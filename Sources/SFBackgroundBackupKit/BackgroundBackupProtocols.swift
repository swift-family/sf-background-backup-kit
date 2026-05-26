import Foundation

@MainActor
public protocol BackgroundBackupSettingsProviding: AnyObject {
    var isBackgroundBackupEnabled: Bool { get }
    var backgroundBackupFrequency: BackgroundBackupFrequency { get }
    var nextBackgroundBackupEarliestDate: Date { get }
}

@MainActor
public protocol BackgroundBackupPerforming: AnyObject {
    func performBackgroundBackupIfNeeded() async throws -> Bool
}
