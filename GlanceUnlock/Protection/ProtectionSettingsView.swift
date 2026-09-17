import SwiftUI

struct ProtectionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: AppProtectionSettings
    @ObservedObject var catalog: ApplicationCatalog
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    let hasFaceProfile: Bool
    let onRequestEnrollment: @MainActor () -> Void
    let onConfigurationChanged: @MainActor () -> Void
    let onSetProtectionEnabled: @MainActor (Bool) -> Void
    let onSetAppProtected: @MainActor (Bool, String) -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(DesignSystem.stroke)

            HStack(spacing: 0) {
                settingsSummary
                    .frame(width: 285)

                Divider().overlay(DesignSystem.stroke)

                applicationsPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 840, idealWidth: 920, minHeight: 610, idealHeight: 680)
        .background(DesignSystem.background)
        .glanceTypography()
        .onAppear {
            catalog.refresh()
            launchAtLogin.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppMark(compact: true)
            Rectangle()
                .fill(DesignSystem.stroke)
                .frame(width: 1, height: 18)
            Text("Protected apps")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignSystem.secondaryText)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(GlanceSecondaryButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
    }

    private var settingsSummary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(settings.isEnabled ? DesignSystem.success.opacity(0.12) : Color.white.opacity(0.05))
                Image(systemName: settings.isEnabled ? "lock.shield.fill" : "lock.shield")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(settings.isEnabled ? DesignSystem.success : DesignSystem.secondaryText)
            }
            .frame(width: 58, height: 58)

            Text("App protection")
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .tracking(-0.8)
                .foregroundStyle(DesignSystem.primaryText)
                .padding(.top, 20)

            Text("Ask for your face or Mac credentials before opening selected apps.")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(DesignSystem.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            Toggle(isOn: enabledBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Protection active")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.primaryText)
                    Text("Continues after this window closes")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(DesignSystem.tertiaryText)
                }
            }
            .toggleStyle(.switch)
            .tint(DesignSystem.success)
            .padding(.top, 25)

            Divider().overlay(DesignSystem.stroke)
                .padding(.vertical, 22)

            VStack(alignment: .leading, spacing: 8) {
                Text("Relock timing")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.primaryText)

                Picker("Relock timing", selection: relockTimingBinding) {
                    ForEach(AppRelockTiming.allCases) { timing in
                        Text(timing.title).tag(timing)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityLabel("Relock timing")

                Text(settings.relockTiming.detail)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignSystem.tertiaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(DesignSystem.stroke)
                .padding(.vertical, 22)

            statusRow(
                symbol: hasFaceProfile ? "faceid" : "face.dashed",
                title: "Face + blink",
                detail: hasFaceProfile ? "Profile ready" : "Not enrolled",
                tint: hasFaceProfile ? DesignSystem.success : DesignSystem.warning
            )

            statusRow(
                symbol: "touchid",
                title: "Mac authentication",
                detail: "Always available",
                tint: DesignSystem.accent
            )
            .padding(.top, 14)

            Divider().overlay(DesignSystem.stroke)
                .padding(.vertical, 22)

            Toggle(isOn: launchAtLoginBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Launch at Login")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.primaryText)
                    Text(launchAtLogin.requiresApproval ? "Approval required in System Settings" : "Keep protection available automatically")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(launchAtLogin.requiresApproval ? DesignSystem.warning : DesignSystem.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .tint(DesignSystem.success)

            if launchAtLogin.requiresApproval {
                Button("Open Login Items Settings") {
                    launchAtLogin.openSystemSettings()
                }
                .buttonStyle(GlanceSecondaryButtonStyle())
                .padding(.top, 12)
            }

            if let errorMessage = launchAtLogin.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignSystem.danger)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .accessibilityLabel("Launch at Login error: \(errorMessage)")
            }

            if !hasFaceProfile {
                Button("Set up face profile") {
                    dismiss()
                    onRequestEnrollment()
                }
                .buttonStyle(GlanceSecondaryButtonStyle())
                .padding(.top, 18)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Privacy layer", systemImage: "info.circle")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignSystem.primaryText.opacity(0.82))
                Text("This does not replace macOS security. Quitting Glance disables app protection, and the normal Mac Lock Screen remains unchanged.")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignSystem.tertiaryText)
                    .lineSpacing(3)
            }
            .padding(14)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DesignSystem.stroke, lineWidth: 1)
            }
            .padding(.top, 24)
            }
            .padding(26)
        }
        .background(DesignSystem.backgroundRaised.opacity(0.48))
    }

    private var applicationsPane: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose applications")
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .tracking(-0.6)
                            .foregroundStyle(DesignSystem.primaryText)
                        Text(settings.relockTiming.detail)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(DesignSystem.secondaryText)
                    }
                    Spacer()
                    Text("\(settings.protectedAppCount) selected")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.tertiaryText)
                }

                HStack(spacing: 10) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DesignSystem.tertiaryText)
                            .accessibilityHidden(true)
                        TextField("Search apps", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(DesignSystem.stroke, lineWidth: 1)
                    }

                    Button {
                        catalog.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 38, height: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignSystem.secondaryText)
                    .accessibilityLabel("Refresh application list")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 18)

            Divider().overlay(DesignSystem.stroke)

            if catalog.isRefreshing {
                Spacer()
                ProgressView("Finding applications…")
                    .font(.system(size: 11, design: .monospaced))
                Spacer()
            } else if filteredApplications.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(DesignSystem.tertiaryText)
                    Text(searchText.isEmpty ? "No applications found" : "No matching applications")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.secondaryText)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredApplications) { application in
                            applicationRow(application)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private var filteredApplications: [ProtectedApplication] {
        guard !searchText.isEmpty else { return catalog.applications }
        return catalog.applications.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { settings.isEnabled },
            set: { enabled in
                onSetProtectionEnabled(enabled)
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        )
    }

    private var relockTimingBinding: Binding<AppRelockTiming> {
        Binding(
            get: { settings.relockTiming },
            set: { timing in
                settings.relockTiming = timing
                onConfigurationChanged()
            }
        )
    }

    private func applicationRow(_ application: ProtectedApplication) -> some View {
        let isProtected = settings.isProtected(application.bundleIdentifier)
        return HStack(spacing: 13) {
            Image(nsImage: application.icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(application.displayName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.primaryText)
                    .lineLimit(1)
                Text(application.bundleIdentifier)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignSystem.tertiaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Toggle("Protect \(application.displayName)", isOn: Binding(
                get: { settings.isProtected(application.bundleIdentifier) },
                set: { protected in
                    onSetAppProtected(protected, application.bundleIdentifier)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(DesignSystem.success)
            .accessibilityLabel("Protect \(application.displayName)")
            .accessibilityValue(isProtected ? "On" : "Off")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 58)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isProtected ? DesignSystem.success.opacity(0.055) : Color.clear)
        )
    }

    private func statusRow(symbol: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.primaryText)
                Text(detail)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignSystem.tertiaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
