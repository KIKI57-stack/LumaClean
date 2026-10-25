import Foundation

enum ScanPhase: Equatable {
    case idle
    case preparing
    case analyzing
    case readingExif
    case grouping
    case finished
}

struct ScanSettings {
    var blurThreshold: Double = 60
    var largeVideoMB: Int = 100
    var includeVideos: Bool = true
    var maxDistance: Int = 6
    var detectWeChat: Bool = true
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    var items: [MediaItem]
    var isExact: Bool

    var best: MediaItem? { items.first }
    var deletable: [MediaItem] { items.count > 1 ? Array(items.dropFirst()) : [] }
    var savings: Int64 { deletable.reduce(Int64(0)) { $0 + $1.displaySize } }
}

struct ScanResult {
    var scannedImages = 0
    var scannedVideos = 0
    var skipped = 0
    var elapsed: TimeInterval = 0

    var duplicateGroups: [DuplicateGroup] = []
    var blurry: [MediaItem] = []
    var screenshots: [MediaItem] = []
    var wechatPhotos: [MediaItem] = []
    var largeVideos: [MediaItem] = []

    var exactGroups: [DuplicateGroup] { duplicateGroups.filter { $0.isExact } }
    var similarGroups: [DuplicateGroup] { duplicateGroups.filter { !$0.isExact } }

    var duplicateCount: Int { duplicateGroups.reduce(0) { $0 + $1.deletable.count } }
    var duplicateSavings: Int64 { duplicateGroups.reduce(Int64(0)) { $0 + $1.savings } }
    var exactSavings: Int64 { exactGroups.reduce(Int64(0)) { $0 + $1.savings } }
    var similarSavings: Int64 { similarGroups.reduce(Int64(0)) { $0 + $1.savings } }
    var screenshotSavings: Int64 { screenshots.reduce(Int64(0)) { $0 + $1.displaySize } }
    var wechatSavings: Int64 { wechatPhotos.reduce(Int64(0)) { $0 + $1.displaySize } }
    var videoSavings: Int64 { largeVideos.reduce(Int64(0)) { $0 + $1.displaySize } }
    var blurrySavings: Int64 { blurry.reduce(Int64(0)) { $0 + $1.displaySize } }

    var reclaimable: Int64 { duplicateSavings + screenshotSavings + videoSavings }

    var hasFindings: Bool {
        !duplicateGroups.isEmpty || !blurry.isEmpty || !screenshots.isEmpty
            || !wechatPhotos.isEmpty || !largeVideos.isEmpty
    }
}
