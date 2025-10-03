//
//  StatusBarItem.swift
//  TimeMachineStatus
//
//  Created by Lukas Pistrol on 2023-11-10.
//
//  Copyright © 2023 Lukas Pistrol. All rights reserved.
//
//  See LICENSE.md for license information.
//  

import Combine
import Logging
import SwiftUI

struct ItemSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct StatusBarItem: View {

    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(StorageKeys.horizontalPadding.id)
    private var padding: Double = StorageKeys.horizontalPadding.default

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

    @AppStorage(StorageKeys.showWarningIcon.id)
    private var showWarningIcon: Bool = StorageKeys.showWarningIcon.default

    @AppStorage(StorageKeys.colorWarningIcon.id)
    private var colorWarningIcon: Bool = StorageKeys.colorWarningIcon.default

    @AppStorage(StorageKeys.iconAlertMode.id)
    private var iconAlertMode: IconAlertMode = StorageKeys.iconAlertMode.default

    @AppStorage(StorageKeys.iconAlertTimeThreshold.id)
    private var iconAlertTimeThreshold: Double = StorageKeys.iconAlertTimeThreshold.default

    var sizePassthrough: PassthroughSubject<CGSize, Never>
    @State var utility: TMUtilityImpl
    @State private var notificationManager = BackupNotificationManager.shared

    private let log = Logger(label: "\(Bundle.identifier).StatusBarItem")

    private var currentIconState: IconState {
        notificationManager.monitoringManager.getCurrentIconState(
            iconAlertMode: iconAlertMode,
            timeThreshold: iconAlertTimeThreshold
        )
    }

    private var mainContent: some View {
        HStack(spacing: spacing) {
            if utility.isIdle {
                // Change the icon to show missed backup warnings based on user settings
                switch currentIconState {
                case .normal:
                    Image(systemSymbol: .clockArrowCirclepath)
                        .font(.body.weight(boldIcon ? .bold : .medium))
                case .warningDefault:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.body.weight(boldIcon ? .bold : .medium))
                case .warningYellow:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.body.weight(boldIcon ? .bold : .medium))
                        .foregroundStyle(.yellow)
                case .warningRed:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.body.weight(boldIcon ? .bold : .medium))
                        .foregroundStyle(.red)
                }
            } else {
                if animateIcon {
                    AnimatedIcon()
                        .font(.body.weight(boldIcon ? .bold : .medium))
                } else {
                    Image(systemSymbol: .arrowTriangle2Circlepath)
                        .font(.body.weight(boldIcon ? .bold : .medium))
                }
            }
            if showStatus, !utility.isIdle {
                Text(utility.status.shortStatusString)
                    .font(.caption2.weight(boldFont ? .bold : .medium))
            }
            if let percentage = utility.status.progessPercentage, showPercentage {
                Text(percentage, format: .percent.precision(.fractionLength(0)))
                    .font(.caption2.weight(boldFont ? .bold : .medium))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(Color.menuBarForeground)
    }

    var body: some View {
        mainContent
            .padding(.horizontal, 4 + padding)
            .frame(maxHeight: .infinity)
            .background(bgColor, in: .rect(cornerRadius: cornerRadius))
            .padding(.vertical, verticalPadding)
            .fixedSize(horizontal: true, vertical: false)
            .overlay(
                GeometryReader { geometryProxy in
                    Color.clear
                        .preference(key: ItemSizePreferenceKey.self, value: geometryProxy.size)
                }
            )
            .onPreferenceChange(ItemSizePreferenceKey.self) { size in
                log.trace("Size: \(size)")
                sizePassthrough.send(size)
            }
            .offset(y: -1)
            .onChange(of: utility.isIdle) { oldValue, newValue in
                log.trace("Changed: \(oldValue) -> \(newValue)")
            }
            .onChange(of: utility.lastUpdated) { _, _ in
                notificationManager.updateDeviceInfo(from: utility.preferences)
            }
            .onAppear {
                notificationManager.updateDeviceInfo(from: utility.preferences)
            }
            .overlay(alignment: .topTrailing) {
                #if DEBUG
                Text("D")
                    .font(.system(size: 6))
                    .bold()
                    .padding(.horizontal, 2)
                    .background(.red, in: .rect(cornerRadius: 3))
                #endif
            }
    }

    struct AnimatedIcon: View {
        @State private var isAnimating = false

        private var rotationAnimation: Animation = .linear(duration: 2).repeatForever(autoreverses: false)

        var body: some View {
            Image(systemSymbol: .arrowTriangle2Circlepath)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0), anchor: .center)
                .animation(rotationAnimation, value: isAnimating)
                .task {
                    isAnimating = true
                }
        }
    }
}

#Preview("Light") {
    StatusBarItem(sizePassthrough: .init(), utility: .init())
        .frame(height: 24)
}

#Preview("Dark") {
    StatusBarItem(sizePassthrough: .init(), utility: .init())
        .frame(height: 24)
        .preferredColorScheme(.dark)
}
