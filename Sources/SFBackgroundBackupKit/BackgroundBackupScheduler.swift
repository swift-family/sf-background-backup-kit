import BackgroundTasks
import Foundation
import OSLog

private let logger = Logger(subsystem: "org.swiftfamily.SFBackgroundBackupKit", category: "BackgroundBackup")

@MainActor
public final class BackgroundBackupScheduler {
    public static let shared = BackgroundBackupScheduler()

    private var configuration: BackgroundBackupConfiguration?
    private weak var settingsProvider: (any BackgroundBackupSettingsProviding)?
    private weak var backupPerformer: (any BackgroundBackupPerforming)?
    private var isRegistered = false

    private init() {}

    @discardableResult
    public func register(
        configuration: BackgroundBackupConfiguration,
        settingsProvider: any BackgroundBackupSettingsProviding,
        backupPerformer: any BackgroundBackupPerforming
    ) -> Bool {
        self.configuration = configuration
        self.settingsProvider = settingsProvider
        self.backupPerformer = backupPerformer

        guard !isRegistered else {
            refreshSchedule()
            return true
        }

        let didRegister = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: configuration.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                logger.error("Received unexpected task type for \(configuration.taskIdentifier, privacy: .public)")
                task.setTaskCompleted(success: false)
                return
            }

            Task { @MainActor in
                self?.handle(task: processingTask)
            }
        }

        isRegistered = didRegister
        logger.debug("Register \(configuration.taskIdentifier, privacy: .public): \(didRegister ? "success" : "failed", privacy: .public)")

        if didRegister {
            refreshSchedule()
        }

        return didRegister
    }

    public func refreshSchedule() {
        guard let configuration else { return }

        if settingsProvider?.isBackgroundBackupEnabled == true {
            submitProcessingRequest(configuration: configuration)
        } else {
            logger.debug("Backup disabled; cancelling pending request")
            cancelPendingBackup()
        }
    }

    public func cancelPendingBackup() {
        guard let taskIdentifier = configuration?.taskIdentifier else { return }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        logger.debug("Cancelled pending request: \(taskIdentifier, privacy: .public)")
    }

    private func handle(task: BGProcessingTask) {
        logger.debug("Task awakened: \(task.identifier, privacy: .public)")
        refreshSchedule()

        guard settingsProvider?.isBackgroundBackupEnabled == true,
              let backupPerformer else {
            logger.debug("Task skipped: backup disabled or performer unavailable")
            task.setTaskCompleted(success: true)
            return
        }

        var didComplete = false
        let operation = Task { @MainActor in
            do {
                logger.debug("Task started backup check")
                let didCreateBackup = try await backupPerformer.performBackgroundBackupIfNeeded()
                logger.debug("\(didCreateBackup ? "Task created backup" : "Task skipped: frequency not due", privacy: .public)")
                didComplete = true
                task.setTaskCompleted(success: true)
                refreshSchedule()
            } catch {
                logger.error("Task failed: \(Self.describe(error), privacy: .public)")
                didComplete = true
                task.setTaskCompleted(success: false)
                refreshSchedule()
            }
        }

        task.expirationHandler = {
            operation.cancel()
            Task { @MainActor in
                guard !didComplete else { return }
                didComplete = true
                logger.error("Task expired")
                task.setTaskCompleted(success: false)
                self.refreshSchedule()
            }
        }
    }

    private func submitProcessingRequest(configuration: BackgroundBackupConfiguration) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: configuration.taskIdentifier)

        let request = BGProcessingTaskRequest(identifier: configuration.taskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        let earliestBeginDate = settingsProvider?.nextBackgroundBackupEarliestDate ?? Date()
        request.earliestBeginDate = earliestBeginDate

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.debug("Submitted request: \(configuration.taskIdentifier, privacy: .public), earliestBeginDate: \(Self.format(earliestBeginDate), privacy: .public)")
        } catch {
            logger.error("Failed to submit request: \(configuration.taskIdentifier, privacy: .public), earliestBeginDate: \(Self.format(earliestBeginDate), privacy: .public), error: \(Self.describe(error), privacy: .public)")
        }
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain)(\(nsError.code)): \(nsError.localizedDescription)"
    }

    private static func format(_ date: Date) -> String {
        if #available(iOS 15.0, macOS 12.0, *) {
            return date.formatted(.iso8601)
        }

        return ISO8601DateFormatter().string(from: date)
    }
}
