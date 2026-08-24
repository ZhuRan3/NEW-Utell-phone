// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NoiseInteropSpike",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-libp2p/swift-noise.git", exact: "0.1.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "4.5.1"),
    ],
    targets: [
        .executableTarget(
            name: "NoiseInteropSpike",
            dependencies: [
                .product(name: "Noise", package: "swift-noise"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
    ]
)
