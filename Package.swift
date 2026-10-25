// Swift Package manifest for Linux/local syntax checks. The iOS app is built by Xcode in CI.
import PackageDescription
let package = Package(name: "LexiDawn", targets: [.executableTarget(name: "LexiDawn", path: "LexiDawn")])
