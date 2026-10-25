// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PhotoSweep",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "PhotoSweep", targets: ["PhotoSweep"])
    ],
    targets: [
        .target(
            name: "PhotoSweep",
            path: "Sources/PhotoSweep"
        )
    ],
    swiftLanguageModes: [.v5]
)
