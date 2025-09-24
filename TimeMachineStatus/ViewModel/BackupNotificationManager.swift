//
//  BackupNotificationManager.swift
//  TimeMachineStatus
//

import Foundation
import Logging
import UserNotifications
import ShellOut

@MainActor
@Observable
class BackupNotificationManager {
    private let log = Logger(label: "\(Bundle.identifier).BackupNotificationManager")
    private let notificationCenter = UNUserNotificationCenter.current()
    private let notificationDelegate = NotificationDelegate()

    var monitoringManager = BackupMonitoringManager()
    private var monitoringTimer: Timer?
    private var hasRequestedPermission = false

    static let shared = BackupNotificationManager()

    init() {
        setupNotificationCenter()
    }

    private func setupNotificationCenter() {
        notificationCenter.delegate = notificationDelegate
    }

    func startMonitoring() {
        guard monitoringManager.isMonitoringEnabled else { return }

        requestNotificationPermissionIfNeeded()

        stopMonitoring()

        let interval = TimeInterval(monitoringManager.checkInterval.rawValue)
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.checkForMissedBackups()
            }
        }

        log.info("Started backup monitoring with \(interval)s interval")
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        log.info("Stopped backup monitoring")
    }

    private func requestNotificationPermissionIfNeeded() {
        guard !hasRequestedPermission else { return }

        Task {
            do {
                let granted = try await notificationCenter.requestAuthorization(
                    options: [.alert, .sound, .badge]
                )
                if granted {
                    log.info("Notification permission granted")
                } else {
                    log.warning("Notification permission denied")
                }
                hasRequestedPermission = true
            } catch {
                log.error("Failed to request notification permission: \(error)")
            }
        }
    }

    func updateDeviceInfo(from preferences: Preferences?) {
        guard let destinations = preferences?.destinations else { return }

        for destination in destinations {
            let lastBackupDate = destination.snapshotDates?.last

            monitoringManager.updateDeviceInfo(
                destinationID: destination.destinationID,
                name: destination.lastKnownVolumeName,
                mountPoint: destination.networkURL,
                lastBackupDate: lastBackupDate
            )

            let config = monitoringManager.getOrCreateConfig(for: destination.destinationID)
            updateBackupSchedule(for: config, destination: destination)
        }
    }

    private func updateBackupSchedule(for config: DeviceMonitoringConfig, destination: Destination) {
        Task {
            do {
                let schedule = try await getTimeMachineSchedule(for: destination)
                config.backupSchedule = schedule
            } catch {
                log.error("Failed to get backup schedule for \(config.destinationID): \(error)")
                config.backupSchedule = .daily
            }
        }
    }

    private func getTimeMachineSchedule(for destination: Destination) async throws -> BackupSchedule {
        let identifiers = [
            destination.networkURL,
            destination.lastKnownVolumeName
        ].compactMap { $0 }

        for identifier in identifiers {
            do {
                let result = try shellOut(to: "tmutil", arguments: ["destinationinfo", "-d", identifier])

                if result.contains("AutoBackupInterval = 3600") {
                    return .hourly
                } else if result.contains("AutoBackupInterval = 86400") {
                    return .daily
                } else if result.contains("AutoBackupInterval = 604800") {
                    return .weekly
                } else {
                    return .daily
                }
            } catch {
                log.warning("Could not get destination info for identifier '\(identifier)': \(error)")
                continue
            }
        }

        log.warning("Could not determine backup schedule using any identifier, defaulting to daily")
        return .daily
    }

    private func checkForMissedBackups() {
        for (destinationID, config) in monitoringManager.deviceConfigs {
            if monitoringManager.shouldSendNotification(for: destinationID) {
                sendNotifications(for: config)
            }
        }
    }

    private func sendNotifications(for config: DeviceMonitoringConfig) {
        // Cancel any existing notification sequence for this device
        config.cancelPendingNotifications()

        // Reset counter and send first notification immediately
        config.notificationsSent = 0
        sendSingleNotificationForConfig(config)

        // Schedule remaining notifications if more than 1
        if config.notificationCount > 1 {
            scheduleNextNotification(for: config)
        }
    }

    private func scheduleNextNotification(for config: DeviceMonitoringConfig) {
        let interval = TimeInterval(config.notificationSpacing.rawValue)

        config.notificationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                // Check if we should still send notifications
                guard config.isMonitored,
                      config.isOverdue,
                      config.notificationsSent < config.notificationCount else {
                    config.cancelPendingNotifications()
                    return
                }

                // Send the notification
                self.sendSingleNotificationForConfig(config)

                // Schedule next notification if we haven't reached the limit
                if config.notificationsSent < config.notificationCount {
                    self.scheduleNextNotification(for: config)
                }
            }
        }
    }

    private func sendSingleNotificationForConfig(_ config: DeviceMonitoringConfig) {
        config.notificationsSent += 1

        let deviceName = config.deviceName ?? "Unknown Device"
        let hoursOverdue = config.hoursOverdue
        let missedBackups = config.consecutiveMissedBackups

        Task {
            await sendSingleNotification(
                deviceName: deviceName,
                hoursOverdue: hoursOverdue,
                missedBackups: missedBackups,
                notificationIndex: config.notificationsSent
            )
        }

        log.info("Sent notification \(config.notificationsSent)/\(config.notificationCount) for \(deviceName) (next in \(config.notificationSpacing.displayName))")
    }

    private func sendSingleNotification(
        deviceName: String,
        hoursOverdue: Int,
        missedBackups: Int,
        notificationIndex: Int
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Time Machine Backup Overdue: \(deviceName)"

        let timeString = hoursOverdue == 1 ? "1 hour" : "\(hoursOverdue) hours"
        let backupString = missedBackups == 1 ? "1 backup" : "\(missedBackups) backups"

        content.body = "Last backup was \(timeString) ago. \(backupString) missed."
        content.sound = .default

        let identifier = "backup-overdue-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        do {
            try await notificationCenter.add(request)
            log.info("Sent notification \(notificationIndex) for \(deviceName)")
        } catch {
            log.error("Failed to send notification: \(error)")
        }
    }

    func resetNotifications(for destinationID: UUID) {
        monitoringManager.resetNotifications(for: destinationID)
    }
}

private class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}