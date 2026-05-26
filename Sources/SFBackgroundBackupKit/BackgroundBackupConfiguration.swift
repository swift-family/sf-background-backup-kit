import Foundation

public enum BackgroundBackupFrequency: Int, Sendable {
    case daily = 0
    case weekly = 1
}

public struct BackgroundBackupConfiguration: Sendable {
    public let taskIdentifier: String
    public let earliestDailyBeginDateOffset: TimeInterval
    public let earliestWeeklyBeginDateOffset: TimeInterval

    public init(
        taskIdentifier: String,
        earliestDailyBeginDateOffset: TimeInterval = 60 * 60,
        earliestWeeklyBeginDateOffset: TimeInterval = 60 * 60 * 24
    ) {
        self.taskIdentifier = taskIdentifier
        self.earliestDailyBeginDateOffset = earliestDailyBeginDateOffset
        self.earliestWeeklyBeginDateOffset = earliestWeeklyBeginDateOffset
    }
}
