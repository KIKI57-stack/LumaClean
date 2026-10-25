import CoreGraphics
import Foundation
import UIKit

enum ImageAnalyzer {
    /// 差值哈希：缩到 9×8 灰度，比较相邻像素，得到 64 bit 指纹。
    /// 两张图汉明距离越小越相似。
    static func dHash(_ image: CGImage) -> UInt64? {
        guard let pixels = grayscalePixels(image, width: 9, height: 8) else { return nil }
        var hash: UInt64 = 0
        var bit = 0
        for y in 0..<8 {
            for x in 0..<8 {
                let left = pixels[y * 9 + x]
                let right = pixels[y * 9 + x + 1]
                if left > right {
                    hash |= (UInt64(1) << UInt64(bit))
                }
                bit += 1
            }
        }
        return hash
    }

    /// 拉普拉斯方差：值越低越模糊。清晰照片通常 > 200，虚焦照片 < 60。
    static func blurScore(_ image: CGImage) -> Double? {
        let width = 128
        let height = 128
        guard let pixels = grayscalePixels(image, width: width, height: height) else { return nil }

        var sum = 0.0
        var sumSquares = 0.0
        var count = 0.0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                let laplacian = Double(
                    Int(pixels[index - width])
                    + Int(pixels[index + width])
                    + Int(pixels[index - 1])
                    + Int(pixels[index + 1])
                    - 4 * Int(pixels[index])
                )
                sum += laplacian
                sumSquares += laplacian * laplacian
                count += 1
            }
        }

        guard count > 0 else { return nil }
        let mean = sum / count
        return sumSquares / count - mean * mean
    }

    static func hamming(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    private static func grayscalePixels(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        let ok = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        return ok ? buffer : nil
    }
}
