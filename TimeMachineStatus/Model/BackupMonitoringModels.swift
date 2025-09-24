//
//  BackupMonitoringModels.swift
//  TimeMachineStatus
//

import Foundation
import Logging
import ShellOut

enum MonitoringInterval: Int, CaseIterable {
    case minutes5 = 300
    case minutes15 = 900
    case minutes30 = 1800
    case hour1 = 3600
    case hours4 = 14400
    case hours8 = 28800
    case day1 = 86400

    var displayName: String {
        switch self {
        case .minutes5: return "Every 5 minutes"
        case .minutes15: return "Every 15 minutes"
        case .minutes30: return "Every 30 minutes"
        case .hour1: return "Every hour"
        case .hours4: return "Every 4 hours"
        case .hours8: return "Every 8 hours"
        case .day1: return "Once per day"
        }
    }
}

enum NotificationSpacing: Int, CaseIterable {
    case minutes5 = 300
    case minutes15 = 900
    case minutes30 = 1800
    case hour1 = 3600
    case hours4 = 14400
    case hours8 = 28800

    var displayName: String {
        switch self {
        case .minutes5: return "5 minutes"
        case .minutes15: return "15 minutes"
        case .minutes30: return "30 minutes"
        case .hour1: return "1 hour"
        case .hours4: return "4 hours"
        case .hours8: return "8 hours"
        }
    }
}

enum BackupSchedule: String, CaseIterable {
    case hourly = "Hourly"
    case daily = "Daily"
    case weekly = "Weekly"
    case custom = "Custom"

    var intervalInSeconds: TimeInterval {
        switch self {
        case .hourly: return 3600
        case .daily: return 86400
        case .weekly: return 604800
        case .custom: return 86400
        }
    }

    var displayName: String {
        switch self {
        case .hourly: return "Backs up: Hourly"
        case .daily: return "Backs up: Daily"
        case .weekly: return "Backs up: Weekly"
        case .custom: return "Backs up: Custom"
        }
    }
}

@Observable
class DeviceMonitoringConfig {
    var destinationID: UUID
    var isMonitored: Bool = false
    var missedBackupThreshold: Int = 1
    var notificationCount: Int = 1
    var notificationSpacing: NotificationSpacing = .minutes30
    var lastNotificationSent: Date?
    var consecutiveMissedBackups: Int = 0
    var backupSchedule: BackupSchedule = .daily
    var customInterval: TimeInterval?

    var deviceName: String?
    var mountPoint: String?
    var lastBackupDate: Date?

    // Track notification state
    var notificationTimer: Timer?
    var notificationsSent: Int = 0

    init(destinationID: UUID) {
        self.destinationID = destinationID
    }

    func cancelPendingNotifications() {
        notificationTimer?.invalidate()
        notificationTimer = nil
        notificationsSent = 0
    }

    var scheduleInterval: TimeInterval {
        if let customInterval = customInterval {
            return customInterval
        }
        return backupSchedule.intervalInSeconds
    }

    var isOverdue: Bool {
        guard let lastBackupDate = lastBackupDate else { return true }
        let timeSinceLastBackup = Date().timeIntervalSince(lastBackupDate)
        return timeSinceLastBackup > scheduleInterval
    }

    var hoursOverdue: Int {
        guard let lastBackupDate = lastBackupDate else { return 0 }
        let timeSinceLastBackup = Date().timeIntervalSince(lastBackupDate)
        let overdueTime = max(0, timeSinceLastBackup - scheduleInterval)
        return Int(overdueTime / 3600)
    }

    var missedBackupCount: Int {
        guard let lastBackupDate = lastBackupDate else { return 1 }
        let timeSinceLastBackup = Date().timeIntervalSince(lastBackupDate)
        let overdueTime = max(0, timeSinceLastBackup - scheduleInterval)
        return max(1, Int(overdueTime / scheduleInterval))
    }
}

@Observable
class BackupMonitoringManager {
    var isMonitoringEnabled: Bool = false
    var checkInterval: MonitoringInterval = .minutes30
    var deviceConfigs: [UUID: DeviceMonitoringConfig] = [:]

    func getOrCreateConfig(for destinationID: UUID) -> DeviceMonitoringConfig {
        if let existing = deviceConfigs[destinationID] {
            return existing
        }

        let config = DeviceMonitoringConfig(destinationID: destinationID)
        deviceConfigs[destinationID] = config
        return config
    }

    func updateDeviceInfo(destinationID: UUID, name: String?, mountPoint: String?, lastBackupDate: Date?) {
        let config = getOrCreateConfig(for: destinationID)
        config.deviceName = name
        config.mountPoint = mountPoint
        config.lastBackupDate = lastBackupDate
    }

    func shouldSendNotification(for destinationID: UUID) -> Bool {
        guard isMonitoringEnabled else { return false }
        let config = getOrCreateConfig(for: destinationID)
        guard config.isMonitored else { return false }
        guard config.isOverdue else {
            config.consecutiveMissedBackups = 0
            return false
        }

        let currentMissedBackups = config.missedBackupCount

        if currentMissedBackups != config.consecutiveMissedBackups {
            config.consecutiveMissedBackups = currentMissedBackups

            if currentMissedBackups >= config.missedBackupThreshold {
                let shouldNotify = config.lastNotificationSent == nil ||
                                  currentMissedBackups > Int((Date().timeIntervalSince(config.lastNotificationSent!) / config.scheduleInterval)) + config.missedBackupThreshold - 1

                if shouldNotify {
                    config.lastNotificationSent = Date()
                    return true
                }
            }
        }

        return false
    }

    func resetNotifications(for destinationID: UUID) {
        if let config = deviceConfigs[destinationID] {
            config.consecutiveMissedBackups = 0
            config.lastNotificationSent = nil
            config.cancelPendingNotifications()
        }
    }
}