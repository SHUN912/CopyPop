// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CopyPop", platforms: [.macOS(.v13)], products: [.executable(name: "CopyPop", targets: ["CopyPop"])], targets: [.executableTarget(name: "CopyPop"), .testTarget(name: "CopyPopTests", dependencies: ["CopyPop"])])
