// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HoneyDueCalSync",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "HoneyDueCalSync",
            path: "Sources/HoneyDueCalSync",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/HoneyDueCalSync/Info.plist"
                ])
            ],
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        ),
        .testTarget(
            name: "HoneyDueCalSyncTests",
            dependencies: ["HoneyDueCalSync"],
            path: "Tests/HoneyDueCalSyncTests"
        )
    ]
)
