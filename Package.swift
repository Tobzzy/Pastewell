// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Pastewell",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pastewell", targets: ["Pastewell"])
    ],
    targets: [
        .executableTarget(
            name: "Pastewell",
            path: "Sources/Pastewell"
        )
    ]
)
