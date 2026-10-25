import Foundation
import Photos
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var authStatus: PHAuthorizationStatus
    @Published var phase: ScanPhase = .idle
    @Published var processed = 0
    @Published var total = 0
    @Published var phaseLabel = ""
    @Published var result: ScanResult?
    @Published var errorMessage: String?
    @Published var toast: String?
    @Published var photoCount = 0
    @Published var videoCount = 0
    @Published var isDeleting = false

    private let library = PhotoLibraryService()
    private var job: Task<Void, Never>?

    init() {
        authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    var isAuthorized: Bool {
        authStatus == .authorized || authStatus == .limited
    }

    var isScanning: Bool {
        phase == .preparing || phase == .analyzing || phase == .readingExif || phase == .grouping
    }

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(processed) / Double(total))
    }

    func requestAccess() async {
        let status = await library.requestAuthorization()
        authStatus = status
        if status == .authorized || status == .limited {
            refreshCounts()
        }
    }

    func refreshCounts() {
        photoCount = PHAsset.fetchAssets(with: .image, options: nil).count
        videoCount = PHAsset.fetchAssets(with: .video, options: nil).count
    }

    func startScan(settings: ScanSettings) {
        job?.cancel()
        job = Task { [weak self] in
            await self?.run(settings: settings)
        }
    }

    func cancelScan() {
        job?.cancel()
        job = nil
        phase = .idle
        result = nil
    }

    func delete(_ items: [MediaItem]) async {
        guard !items.isEmpty, !isDeleting else { return }
        isDeleting = true
        let bytes = items.reduce(Int64(0)) { $0 + $1.displaySize }
        do {
            try await library.delete(items.map { $0.asset })
            removeFromResult(items)
            toast = "已删除 \(items.count) 项 · 释放约 \(Fmt.size(bytes))"
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
        isDeleting = false
    }

    // MARK: - 扫描流程

    private func run(settings: ScanSettings) async {
        phase = .preparing
        phaseLabel = "读取相册…"
        processed = 0
        total = 0
        result = nil
        errorMessage = nil

        let startedAt = Date()
        let assets = library.fetchAssets(includeVideos: settings.includeVideos)
        total = assets.count

        guard !assets.isEmpty else {
            result = ScanResult()
            phase = .finished
            return
        }

        phase = .analyzing
        phaseLabel = "分析画面…"

        var items: [MediaItem] = []
        items.reserveCapacity(assets.count)

        let batchSize = 24
        var cursor = 0

        while cursor < assets.count {
            if Task.isCancelled {
                phase = .idle
                return
            }

            let end = min(cursor + batchSize, assets.count)
            let slice = Array(assets[cursor..<end])
            let measured = await measure(slice)

            for (offset, asset) in slice.enumerated() {
                var item = MediaItem(asset: asset)
                if let value = measured[offset] {
                    item.hash = value.0
                    item.blur = value.1
                }
                items.append(item)
            }

            cursor = end
            processed = items.count
            await Task.yield()
        }

        if Task.isCancelled {
            phase = .idle
            return
        }

        if settings.detectWeChat {
            phase = .readingExif
            phaseLabel = "读取拍摄信息…"

            let targets = items.indices.filter { !items[$0].isVideo && !items[$0].isScreenshot }
            total = targets.count
            processed = 0

            let exifBatch = 16
            var exifCursor = 0

            while exifCursor < targets.count {
                if Task.isCancelled {
                    phase = .idle
                    return
                }

                let end = min(exifCursor + exifBatch, targets.count)
                let indices = Array(targets[exifCursor..<end])
                let assets = indices.map { items[$0].asset }
                let metas = await inspect(assets)

                for (offset, itemIndex) in indices.enumerated() {
                    guard let meta = metas[offset] else { continue }
                    let verdict = WeChatDetector.evaluate(meta)
                    items[itemIndex].wechatScore = verdict.score
                    items[itemIndex].wechatReasons = verdict.reasons
                    if meta.byteCount > 0 {
                        items[itemIndex].fileSize = meta.byteCount
                    }
                }

                exifCursor = end
                processed = exifCursor
                await Task.yield()
            }
        }

        if Task.isCancelled {
            phase = .idle
            return
        }

        phase = .grouping
        phaseLabel = "比对相似照片…"
        await Task.yield()

        let images = items.filter { !$0.isVideo }
        let rawGroups = DuplicateGrouper.groups(from: images, maxDistance: settings.maxDistance)

        var duplicateGroups: [DuplicateGroup] = []
        for raw in rawGroups {
            var group = raw
            for index in group.indices {
                fillSize(&group[index])
            }
            group.sort { lhs, rhs in
                if lhs.pixelCount != rhs.pixelCount { return lhs.pixelCount > rhs.pixelCount }
                if lhs.displaySize != rhs.displaySize { return lhs.displaySize > rhs.displaySize }
                return (lhs.blur ?? 0) > (rhs.blur ?? 0)
            }
            let exact = DuplicateGrouper.maxPairwiseDistance(group) <= 3
            duplicateGroups.append(DuplicateGroup(items: group, isExact: exact))
        }
        duplicateGroups.sort { $0.savings > $1.savings }

        var blurry = images.filter { item in
            guard !item.isScreenshot, let score = item.blur else { return false }
            return score < settings.blurThreshold
        }
        blurry.sort { ($0.blur ?? 0) < ($1.blur ?? 0) }
        if blurry.count > 400 {
            blurry = Array(blurry.prefix(400))
        }

        var screenshots = images.filter { $0.isScreenshot }
        for index in screenshots.indices {
            fillSize(&screenshots[index])
        }
        screenshots.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }

        var wechatPhotos: [MediaItem] = []
        if settings.detectWeChat {
            wechatPhotos = images.filter { $0.wechatScore >= WeChatDetector.threshold }
            wechatPhotos.sort { lhs, rhs in
                if lhs.wechatScore != rhs.wechatScore { return lhs.wechatScore > rhs.wechatScore }
                return (lhs.creationDate ?? .distantPast) > (rhs.creationDate ?? .distantPast)
            }
        }

        let threshold = Int64(settings.largeVideoMB) * 1024 * 1024
        var videos = items.filter { $0.isVideo }
        for index in videos.indices {
            fillSize(&videos[index])
        }
        videos = videos.filter { $0.displaySize >= threshold }
        videos.sort { $0.displaySize > $1.displaySize }

        var scanResult = ScanResult()
        scanResult.scannedImages = images.count
        scanResult.scannedVideos = items.count - images.count
        scanResult.skipped = images.filter { $0.hash == nil }.count
        scanResult.elapsed = Date().timeIntervalSince(startedAt)
        scanResult.duplicateGroups = duplicateGroups
        scanResult.blurry = blurry
        scanResult.screenshots = screenshots
        scanResult.wechatPhotos = wechatPhotos
        scanResult.largeVideos = videos

        result = scanResult
        phase = .finished
    }

    private func measure(_ slice: [PHAsset]) async -> [Int: (UInt64?, Double?)] {
        await withTaskGroup(
            of: (Int, UInt64?, Double?).self,
            returning: [Int: (UInt64?, Double?)].self
        ) { group in
            var collected: [Int: (UInt64?, Double?)] = [:]

            for (offset, asset) in slice.enumerated() where asset.mediaType == .image {
                group.addTask {
                    let service = PhotoLibraryService()
                    guard let image = await service.analysisImage(for: asset) else {
                        return (offset, nil, nil)
                    }
                    return (offset, ImageAnalyzer.dHash(image), ImageAnalyzer.blurScore(image))
                }
            }

            for await value in group {
                collected[value.0] = (value.1, value.2)
            }
            return collected
        }
    }

    /// 只在能读到真实大小时才覆盖，避免把前面 EXIF 阶段读到的字节数抹成 0。
    private func fillSize(_ item: inout MediaItem) {
        let size = MediaItem.resourceSize(of: item.asset)
        if size > 0 { item.fileSize = size }
    }

    private func inspect(_ assets: [PHAsset]) async -> [Int: PhotoMetadata] {
        await withTaskGroup(
            of: (Int, PhotoMetadata?).self,
            returning: [Int: PhotoMetadata].self
        ) { group in
            var collected: [Int: PhotoMetadata] = [:]

            for (offset, asset) in assets.enumerated() {
                group.addTask {
                    let meta = await ExifInspector.metadata(for: asset)
                    return (offset, meta)
                }
            }

            for await value in group {
                if let meta = value.1 {
                    collected[value.0] = meta
                }
            }
            return collected
        }
    }

    private func removeFromResult(_ items: [MediaItem]) {
        guard var snapshot = result else { return }
        let ids = Set(items.map { $0.id })

        snapshot.blurry.removeAll { ids.contains($0.id) }
        snapshot.screenshots.removeAll { ids.contains($0.id) }
        snapshot.wechatPhotos.removeAll { ids.contains($0.id) }
        snapshot.largeVideos.removeAll { ids.contains($0.id) }
        snapshot.duplicateGroups = snapshot.duplicateGroups.compactMap { group in
            var copy = group
            copy.items.removeAll { ids.contains($0.id) }
            return copy.items.count >= 2 ? copy : nil
        }

        result = snapshot
    }
}
