import Foundation
import ImageIO
import Photos

struct PhotoMetadata {
    var make: String?
    var model: String?
    var hasAppleMakerNote: Bool
    var hasLensModel: Bool
    var hasExposure: Bool
    var hasGPS: Bool
    var hasCaptureDate: Bool
    var pixelWidth: Int
    var pixelHeight: Int
    var byteCount: Int64
}

enum ExifInspector {
    /// 只读文件头和属性字典，不解码像素，所以比取缩略图还便宜。
    static func metadata(for asset: PHAsset) async -> PhotoMetadata? {
        guard let data = await imageData(for: asset) else { return nil }
        return parse(data)
    }

    private static func imageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false
            options.version = .current

            var resumed = false
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: data)
            }
        }
    }

    static func parse(_ data: Data) -> PhotoMetadata? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else { return nil }

        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]

        let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0

        return PhotoMetadata(
            make: tiff[kCGImagePropertyTIFFMake as String] as? String,
            model: tiff[kCGImagePropertyTIFFModel as String] as? String,
            hasAppleMakerNote: exif["MakerApple"] != nil,
            hasLensModel: exif[kCGImagePropertyExifLensModel as String] != nil,
            hasExposure: exif[kCGImagePropertyExifExposureTime as String] != nil
                || exif[kCGImagePropertyExifFNumber as String] != nil
                || exif[kCGImagePropertyExifISOSpeedRatings as String] != nil,
            hasGPS: !gps.isEmpty,
            hasCaptureDate: exif[kCGImagePropertyExifDateTimeOriginal as String] != nil,
            pixelWidth: width,
            pixelHeight: height,
            byteCount: Int64(data.count)
        )
    }
}
