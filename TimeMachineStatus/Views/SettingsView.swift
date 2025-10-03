//
//  SettingsView.swift
//  TimeMachineStatus
//
//  Created by Lukas Pistrol on 2023-11-10.
//
//  Copyright © 2023 Lukas Pistrol. All rights reserved.
//
//  See LICENSE.md for license information.
//  

import Logging
import Sparkle
import SwiftUI

enum StorageKeys {

    struct Key<Value: Any> {
        let id: String
        let `default`: Value
    }

    static let horizontalPadding = Key(id: "horizontalPadding", default: 0.0)
    static let verticalPadding = Key(id: "verticalPadding", default: 0.0)
    static let boldFont = Key(id: "boldFont", default: false)
    static let boldIcon = Key(id: "boldIcon", default: false)
    static let showStatus = Key(id: "showStatus", default: true)
    static let spacing = Key(id: "spacing", default: 4.0)
    static let backgroundColor = Key(id: "backgroundColor", default: Color.clear)
    static let cornerRadius = Key(id: "cornerRadius", default: 5.0)
    static let showPercentage = Key(id: "showPercentage", default: true)
    static let animateIcon = Key(id: "animateIcon", default: true)

    static let logLevel = Key(id: "logLevel", default: Logger.Level.info)
    static let showWarningIcon = Key(id: "showWarningIcon", default: false)
    static let colorWarningIcon = Key(id: "colorWarningIcon", default: false)
    static let iconAlertMode = Key(id: "iconAlertMode", default: IconAlertMode.none)
    static let iconAlertTimeThreshold = Key(id: "iconAlertTimeThreshold", default: 24.0)
}

struct SettingsView: View {

    @AppStorage(StorageKeys.horizontalPadding.id)
    private var horizontalPadding: Double = StorageKeys.horizontalPadding.default

    @AppStorage(StorageKeys.verticalPadding.id)
    private var verticalPadding: Double = StorageKeys.verticalPadding.default

    @AppStorage(StorageKeys.boldFont.id)
    private var boldFont: Bool = StorageKeys.boldFont.default

    @AppStorage(StorageKeys.boldIcon.id)
    private var boldIcon: Bool = StorageKeys.boldIcon.default

    @AppStorage(StorageKeys.showStatus.id)
    private var showStatus: Bool = StorageKeys.showStatus.default

    @AppStorage(StorageKeys.showPercentage.id)
    private var showPercentage: Bool = StorageKeys.showPercentage.default

    @AppStorage(StorageKeys.spacing.id)
    private var spacing: Double = StorageKeys.spacing.default

    @AppStorage(StorageKeys.backgroundColor.id)
    private var bgColor: Color = StorageKeys.backgroundColor.default

    @AppStorage(StorageKeys.cornerRadius.id)
    private var cornerRadius: Double = StorageKeys.cornerRadius.default

    @AppStorage(StorageKeys.animateIcon.id)
    private var animateIcon: Bool = StorageKeys.animateIcon.default

    @AppStorage(StorageKeys.logLevel.id)
    private var logLevel: Logger.Level = StorageKeys.logLevel.default

    @AppStorage(StorageKeys.showWarningIcon.id)
    private var showWarningIcon: Bool = StorageKeys.showWarningIcon.default

    @AppStorage(StorageKeys.colorWarningIcon.id)
    private var colorWarningIcon: Bool = StorageKeys.colorWarningIcon.default

    @AppStorage(StorageKeys.iconAlertMode.id)
    private var iconAlertMode: IconAlertMode = StorageKeys.iconAlertMode.default

    @AppStorage(StorageKeys.iconAlertTimeThreshold.id)
    private var iconAlertTimeThreshold: Double = StorageKeys.iconAlertTimeThreshold.default

    enum Tabs: Hashable, CaseIterable {
        case general
        case appearance
        case notifications
        case about

        var height: Double {
            switch self {
            case .about: 350
            case .appearance: 450
            case .general: 320
            case .notifications: 400
            }
        }

        static var largestHeight: Double {
            Self.allCases.map(\.height).max() ?? 100
        }
    }

    @State private var selection: Tabs
    @StateObject private var launchItemProvider = LaunchItemProvider()
    @ObservedObject private var updaterViewModel: UpdaterViewModel
    @State private var utility: any TMUtility
    @State private var notificationManager = BackupNotificationManager.shared
    private let updater: SPUUpdater

    init(updater: SPUUpdater, utility: any TMUtility, selection: Tabs = .general) {
        self.updater = updater
        self.updaterViewModel = UpdaterViewModel(updater: updater)
        self.utility = utility
        self.selection = selection
    }

    var body: some View {
        TabView(selection: $selection) {
            generalTab
            appearandeTab
            notificationsTab
            aboutTab
        }
        .frame(
            width: Constants.Sizes.settingsWidth,
            height: isPreview ? Tabs.largestHeight : selection.height
        )
        .onAppear {
            notificationManager.updateDeviceInfo(from: utility.preferences)
        }
        .onChange(of: utility.lastUpdated) { _, _ in
            notificationManager.updateDeviceInfo(from: utility.preferences)
        }
    }

    @State private var showPicker: Bool = false

    private var generalTab: some View {
        Form {
            if !utility.canReadPreferences {
                Section("settings_section_permissions") {
                    VStack(alignment: .leading) {
                        Text("settings_item_preferences_file_permission")
                            .font(.callout)
                    }
                    HStack {
                        Spacer()
                        Button("button_grant_access") {
                            showPicker = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            Section {
                VStack(alignment: .leading) {
                    Toggle("settings_item_launchatlogin", isOn: $launchItemProvider.launchAtLogin)
                        .disabled(launchItemProvider.requiresApproval)
                    if launchItemProvider.requiresApproval {
                        Text("settings_item_launchatlogin_approval_notice")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(
                    "settings_item_autocheckupdates",
                    isOn: $updaterViewModel.automaticallyChecksForUpdates
                )
            }
            Section {
                Picker("settings_item_loglevel", selection: $logLevel) {
                    Text("settings_item_loglevel_debug").tag(Logger.Level.trace)
                    Text("settings_item_loglevel_info").tag(Logger.Level.info)
                }
            } footer: {
                Text("settings_item_loglevel_footer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .tabItem {
            Label("settings_tab_item_general", systemSymbol: .gear)
        }
        .tag(Tabs.general)
        .preferencesFileImporter($showPicker)
    }

    private var appearandeTab: some View {
        Form {
            Section("settings_section_menubaritem") {
                LabeledContent {
                    HStack {
                        Text(horizontalPadding.formatted(.number) + " pt")
                        Stepper("", value: $horizontalPadding, in: 0...10, step: 1)
                            .labelsHidden()
                    }
                } label: {
                    Text("settings_item_horizontalpadding")
                }
            }
            Section {
                HStack {
                    ColorPicker("settings_item_backgroundcolor", selection: $bgColor)
                    Button("settings_button_default") {
                        bgColor = .clear
                    }
                }
                if bgColor.cgColor?.alpha != 0 {
                    LabeledContent {
                        HStack {
                            Text(verticalPadding.formatted(.number) + " pt")
                            Stepper("", value: $verticalPadding, in: 0...5, step: 1)
                                .labelsHidden()
                        }
                    } label: {
                        Text("settings_item_verticalpadding")
                    }
                    LabeledContent {
                        HStack {
                            Text(cornerRadius.formatted(.number) + " pt")
                            Stepper("", value: $cornerRadius, in: 0...12, step: 1)
                                .labelsHidden()
                        }
                    } label: {
                        Text("settings_item_cornerradius")
                    }
                }
            }
            Section {
                Toggle("settings_item_boldfont", isOn: $boldFont)
                Toggle("settings_item_boldicon", isOn: $boldIcon)
            }
            Section {
                Toggle("settings_item_animateicon", isOn: $animateIcon)
                Toggle("settings_item_showstatus", isOn: $showStatus)
                Toggle("settings_item_showpercentage", isOn: $showPercentage)
                if showStatus || showPercentage {
                    LabeledContent {
                        HStack {
                            Text(spacing.formatted(.number) + " pt")
                            Stepper("", value: $spacing, in: 2...12, step: 1)
                                .labelsHidden()
                        }
                    } label: {
                        Text("settings_item_spacing")
                    }
                }
            }
            Section {
                HStack {
                    Spacer()
                    Button("settings_button_resettodefault", role: .destructive) {
                        horizontalPadding = StorageKeys.horizontalPadding.default
                        verticalPadding = StorageKeys.verticalPadding.default
                        boldFont = StorageKeys.boldFont.default
                        boldIcon = StorageKeys.boldIcon.default
                        showStatus = StorageKeys.showStatus.default
                        showPercentage = StorageKeys.showPercentage.default
                        spacing = StorageKeys.spacing.default
                        bgColor = StorageKeys.backgroundColor.default
                        cornerRadius = StorageKeys.cornerRadius.default
                    }
                }
            }
        }
        .formStyle(.grouped)
        .tabItem {
            Label("settings_tab_item_appearance", systemSymbol: .wandAndStarsInverse)
        }
        .tag(Tabs.appearance)
    }

    private var notificationsTab: some View {
        Form {
            globalMonitoringSettingsSection
            iconAlertSettingsSection
            if let destinations = utility.preferences?.destinations, !destinations.isEmpty {
                deviceMonitoringSettingsSection(destinations: destinations)
            }
        }
        .formStyle(.grouped)
        .tabItem {
            Label("Notifications", systemImage: "bell")
        }
        .tag(Tabs.notifications)
        .onChange(of: notificationManager.monitoringManager.isMonitoringEnabled) { _, isEnabled in
            if isEnabled {
                notificationManager.startMonitoring()
            } else {
                notificationManager.stopMonitoring()
            }
        }
        .onChange(of: notificationManager.monitoringManager.checkInterval) { _, _ in
            if notificationManager.monitoringManager.isMonitoringEnabled {
                notificationManager.startMonitoring()
            }
        }
    }

    private var globalMonitoringSettingsSection: some View {
        Section("Backup Monitoring") {
            Toggle("Enable Backup Monitoring", isOn: $notificationManager.monitoringManager.isMonitoringEnabled)
                .onChange(of: notificationManager.monitoringManager.isMonitoringEnabled) { _, isEnabled in
                    if isEnabled {
                        notificationManager.updateDeviceInfo(from: utility.preferences)
                    }
                }

            if notificationManager.monitoringManager.isMonitoringEnabled {
                Picker("Check for missed backups", selection: $notificationManager.monitoringManager.checkInterval) {
                    ForEach(MonitoringInterval.allCases, id: \.rawValue) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var iconAlertSettingsSection: some View {
        Section("Icon Alerts") {
            Picker("Alert mode", selection: $iconAlertMode) {
                ForEach(IconAlertMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)

            if iconAlertMode == .countBased {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Yellow: 1 missed backup")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Red: 2+ missed backups")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 8)
            }

            if iconAlertMode == .timeBased {
                HStack {
                    Text("Alert threshold:")
                    TextField("", value: $iconAlertTimeThreshold, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Text("hour\(Int(iconAlertTimeThreshold) == 1 ? "" : "s")")
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Yellow: After \(Int(iconAlertTimeThreshold)) hours")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Red: After \(Int(iconAlertTimeThreshold * 2)) hours")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 8)
            }
        }
    }

    private func deviceMonitoringSettingsSection(destinations: [Destination]) -> some View {
        Section("Time Machine Destinations") {
            ForEach(destinations, id: \.destinationID) { destination in
                let config = notificationManager.monitoringManager.getOrCreateConfig(for: destination.destinationID)

                DeviceConfigRow(
                    destination: destination,
                    config: config,
                    isGloballyEnabled: notificationManager.monitoringManager.isMonitoringEnabled
                )
            }
        }
    }

    private var aboutTab: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128)
                Text(Bundle.appName)
                    .font(.title)
                    .fontWeight(.bold)
                Text("Version " + Bundle.appVersionString + " (" + Bundle.appBuildString + ")")
                    .font(.headline)
                Button("settings_button_checkforupdates") {
                    updater.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }
            VStack {
                Text("about_copyright")
                Link("about_weblink", destination: Constants.URLs.authorURL)
            }
            .font(.caption2)
        }
        .tabItem {
            Label("settings_tab_item_about", systemSymbol: .infoCircle)
        }
        .tag(Tabs.about)
    }
}

private struct DeviceConfigRow: View {
    let destination: Destination
    @State var config: DeviceMonitoringConfig
    let isGloballyEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.lastKnownVolumeName ?? "Unknown Device")
                        .font(.headline)
                    if let networkURL = destination.networkURL {
                        Text(networkURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("Monitor this device", isOn: $config.isMonitored)
                    .labelsHidden()
                    .disabled(!isGloballyEnabled)
            }

            if config.isMonitored && isGloballyEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Alert after")
                        Stepper(
                            value: $config.missedBackupThreshold,
                            in: 1...10,
                            step: 1
                        ) {
                            Text("\(config.missedBackupThreshold) missed backup\(config.missedBackupThreshold == 1 ? "" : "s")")
                        }
                    }

                    HStack(spacing: 4) {
                        Text("Send")
                        Stepper(
                            value: $config.notificationCount,
                            in: 1...5,
                            step: 1
                        ) {
                            Text("\(config.notificationCount) notification\(config.notificationCount == 1 ? "" : "s...")")
                        }
                    }

                    if config.notificationCount > 1 {
                        HStack(spacing: 4) {
                            Text("...every")
                            Picker("", selection: $config.notificationSpacing) {
                                ForEach(NotificationSpacing.allCases, id: \.rawValue) { spacing in
                                    Text(spacing.displayName).tag(spacing)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(config.backupSchedule.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let lastBackupDate = destination.snapshotDates?.last {
                            let timeString: String = {
                                let formatter = RelativeDateTimeFormatter()
                                formatter.unitsStyle = .full
                                return formatter.localizedString(for: lastBackupDate, relativeTo: Date())
                            }()
                            Text("Last backup: \(timeString)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Last backup: Never")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            config.deviceName = destination.lastKnownVolumeName
            config.mountPoint = destination.networkURL
            config.lastBackupDate = destination.snapshotDates?.last
        }
    }
}

#Preview("General/Default") {
    SettingsView(
        updater: SPUStandardUpdaterController(updaterDelegate: nil, userDriverDelegate: nil).updater,
        utility: TMUtilityMock(),
        selection: .general
    )
}

#Preview("General/No Permission") {
    SettingsView(
        updater: SPUStandardUpdaterController(updaterDelegate: nil, userDriverDelegate: nil).updater,
        utility: TMUtilityMock(error: .preferencesFilePermissionNotGranted, canReadPreferences: false),
        selection: .general
    )
}

#Preview("Appearance") {
    SettingsView(
        updater: SPUStandardUpdaterController(updaterDelegate: nil, userDriverDelegate: nil).updater,
        utility: TMUtilityMock(),
        selection: .appearance
    )
}

#Preview("About") {
    SettingsView(
        updater: SPUStandardUpdaterController(updaterDelegate: nil, userDriverDelegate: nil).updater,
        utility: TMUtilityMock(),
        selection: .about
    )
}
