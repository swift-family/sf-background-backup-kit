// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "sf-background-backup-kit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SFBackgroundBackupKit",
            targets: ["SFBackgroundBackupKit"]
        )
    ],
    targets: [
        .target(
            name: "SFBackgroundBackupKit"
        )
    ]
)
