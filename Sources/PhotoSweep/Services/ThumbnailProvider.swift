import Foundation
import Photos
import UIKit

final class ThumbnailProvider {
    static let shared = ThumbnailProvider()

    private let manager = PHCachingImageManager()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 600
    }

    func image(for asset: PHAsset, size: CGSize) async -> UIImage? {
        let key = "\(asset.localIdentifier)_\(Int(size.width))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image = await request(asset: asset, size: size)
        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }

    private func request(asset: PHAsset, size: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            var resumed = false
            manager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }
}
