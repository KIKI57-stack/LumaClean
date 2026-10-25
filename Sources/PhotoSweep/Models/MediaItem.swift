import Foundation
import Photos

struct MediaItem: Identifiable, Hashable {
    let asset: PHAsset
    var hash: UInt64? = nil
    var blur: Double? = nil
    var fileSize: Int64 = 0
    var wechatScore: Double = 0
    var wechatReasons: [String] = []

    var id: String { asset.localIdentifier }
    var pixelWidth: Int { asset.pixelWidth }
    var pixelHeight: Int { asset.pixelHeight }
    var pixelCount: Int { asset.pixelWidth * asset.pixelHeight }
    var creationDate: Date? { asset.creationDate }
    var isVideo: Bool { asset.mediaType == .video }
    var isScreenshot: Bool { asset.mediaSubtypes.contains(.photoScreenshot) }
    var megapixels: Double { Double(pixelCount) / 1_000_000.0 }

    /// 优先用真实文件大小；拿不到时按像素/时长估算，仅用于界面展示。
    var displaySize: Int64 {
        if fileSize > 0 { return fileSize }
        if isVideo { return Int64(asset.duration * 2_500_000) }
        return Int64(Double(pixelCount) * 0.5)
    }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func resourceSize(of asset: PHAsset) -> Int64 {
        let selector = NSSelectorFromString("fileSize")
        var total: Int64 = 0
        for resource in PHAssetResource.assetResources(for: asset) {
            guard resource.responds(to: selector) else { continue }
            if let number = resource.value(forKey: "fileSize") as? NSNumber {
                total += number.int64Value
            }
        }
        return total
    }
}
