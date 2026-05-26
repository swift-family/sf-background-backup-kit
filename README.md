# SFBackgroundBackupKit

Initial version: `0.0.1`

`SFBackgroundBackupKit` is a small iOS helper package for scheduling app-defined backup work with `BGTaskScheduler`.

The package owns the background scheduling lifecycle. The app still owns its actual backup implementation, settings storage, `Info.plist` capabilities, and any database-specific behavior.

## Responsibilities

The package handles:

- Registering a `BGProcessingTask` identifier.
- Submitting or cancelling pending background backup requests.
- Calling the app-provided backup performer when iOS wakes the task.
- Resubmitting the next request whenever a task is handled.

The app handles:

- Adding `BGTaskSchedulerPermittedIdentifiers` to `Info.plist`.
- Adding `processing` to `UIBackgroundModes`.
- Providing the current backup settings.
- Performing the actual backup work.

## Usage

Register the scheduler during app startup, before the app finishes launching:

```swift
import SFBackgroundBackupKit

BackgroundBackupScheduler.shared.register(
    configuration: BackgroundBackupConfiguration(
        taskIdentifier: AppConstants.BackgroundBackup.taskIdentifier
    ),
    settingsProvider: SettingsManager.shared,
    backupPerformer: BackupService.shared
)
```

When the app enters the background, refresh the pending request:

```swift
BackgroundBackupScheduler.shared.refreshSchedule()
```

When the user changes backup settings, call `refreshSchedule()` again. If backup is disabled, the scheduler cancels the pending request.

## Protocols

Settings providers expose whether background backup is enabled and which cadence the app wants:
They also provide the next earliest date the scheduler should submit to `BGTaskScheduler`.

```swift
@MainActor
public protocol BackgroundBackupSettingsProviding: AnyObject {
    var isBackgroundBackupEnabled: Bool { get }
    var backgroundBackupFrequency: BackgroundBackupFrequency { get }
    var nextBackgroundBackupEarliestDate: Date { get }
}
```

Backup performers run app-specific work and return whether a backup was created:

```swift
@MainActor
public protocol BackgroundBackupPerforming: AnyObject {
    func performBackgroundBackupIfNeeded() async throws -> Bool
}
```

## Info.plist

The host app must include the task identifier:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>org.swiftfamily.yourapp.background-backup</string>
</array>
```

Keep this value in sync with the Swift constant passed to `BackgroundBackupConfiguration.taskIdentifier`.

The host app must also include the background processing mode:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
</array>
```

Keep any existing background modes that the app already uses.

## Notes

iOS decides when background processing tasks actually run. `earliestBeginDate` is only a hint, not a guarantee. This package is best for opportunistic local backups such as SQLite snapshots, where exact timing is not required.
