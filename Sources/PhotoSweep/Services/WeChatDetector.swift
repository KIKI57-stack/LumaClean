import Foundation
import Photos

enum WeChatDetector {
    /// 达到这个分数就进「微信相机」列表。
    static let threshold: Double = 5.0

    struct Verdict {
        var score: Double
        var reasons: [String]
        var isCandidate: Bool { score >= threshold }
    }

    /// 判定逻辑：
    /// 微信相机拍完会用 UIImage 重新压缩再存相册，JPEG 重编码会丢掉全部 EXIF。
    /// 而 iPhone 原生相机一定会写 Make/Model/MakerNote/镜头/曝光参数。
    /// 所以「完全没有相机元数据」是微信相机的典型指纹。
    ///
    /// 副作用：网页保存的图、其他 App 保存的图也会命中，需要人工过一眼。
    static func evaluate(_ meta: PhotoMetadata) -> Verdict {
        var score = 0.0
        var reasons: [String] = []

        let make = (meta.make ?? "").lowercased()
        let isApple = make.contains("apple")

        // 有 Apple MakerNote + Apple 厂商 = 铁定原生相机，直接排除
        if isApple && meta.hasAppleMakerNote {
            return Verdict(score: 0, reasons: [])
        }

        if meta.make == nil {
            score += 2.0
            reasons.append("无厂商信息")
        } else if !isApple {
            score += 1.0
            reasons.append("非 Apple 厂商")
        }

        if meta.model == nil {
            score += 1.5
            reasons.append("无机型信息")
        }

        if !meta.hasAppleMakerNote {
            score += 1.5
            reasons.append("无 Apple 原始数据")
        }

        if !meta.hasLensModel && !meta.hasExposure {
            score += 1.5
            reasons.append("无镜头与曝光参数")
        }

        if !meta.hasGPS {
            score += 0.5
            reasons.append("无定位")
        }

        if !meta.hasCaptureDate {
            score += 0.5
            reasons.append("无拍摄时间")
        }

        let longEdge = max(meta.pixelWidth, meta.pixelHeight)
        if longEdge > 0 && longEdge <= 2048 {
            score += 0.5
            reasons.append("分辨率偏低")
        }

        let pixels = Double(meta.pixelWidth * meta.pixelHeight)
        if pixels > 0 {
            let bytesPerPixel = Double(meta.byteCount) / pixels
            if bytesPerPixel < 0.25 {
                score += 0.5
                reasons.append("压缩率偏高")
            }
        }

        return Verdict(score: score, reasons: reasons)
    }
}
