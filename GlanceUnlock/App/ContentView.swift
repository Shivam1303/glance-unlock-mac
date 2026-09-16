import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingEnrollment = false
    @State private var enrollAfterSettingsDismiss = false
    @State private var confirmingProfileReset = false
    #if DEBUG
    @State private var showingDeveloperTuning = false
    #endif

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DesignSystem.background.ignoresSafeArea()
                ambientBackground

                VStack(spacing: 0) {
                    header
                    if proxy.size.width >= 960 {
                        HStack(spacing: 64) {
                            hero
                                .frame(maxWidth: 530, alignment: .leading)
                            SecurityVisual(hasProfile: model.hasProfile, reduceMotion: reduceMotion)
                                .frame(maxWidth: 380)
                        }
                        .frame(maxWidth: 1080)
                        .padding(.horizontal, 48)
                        .frame(maxHeight: .infinity)
                    } else {
                        VStack(spacing: 30) {
                            SecurityVisual(hasProfile: model.hasProfile, reduceMotion: true, compact: true)
                                .frame(height: 150)
                            hero
                                .frame(maxWidth: 590, alignment: .leading)
                        }
                        .padding(.horizontal, 40)
                        .frame(maxHeight: .infinity)
                    }
                    footer
                }
            }
        }
        .glanceTypography()
        .onAppear { model.startProtectionMonitoring() }
        .sheet(isPresented: $showingEnrollment, onDismiss: model.refreshProfile) {
            EnrollmentView(
                camera: model.camera,
                store: model.profileStore,
                featurePrintService: model.featurePrintService
            )
        }
        #if DEBUG
        .sheet(isPresented: $showingDeveloperTuning) { DeveloperTuningView() }
        #endif
        .sheet(isPresented: $model.isSafeLockPresented) {
            PrototypeLockView(
                camera: model.camera,
                store: model.profileStore,
                featurePrintService: model.featurePrintService
            )
        }
        .sheet(isPresented: $model.isProtectionSettingsPresented, onDismiss: {
            if enrollAfterSettingsDismiss {
                enrollAfterSettingsDismiss = false
                showingEnrollment = true
            }
        }) {
            ProtectionSettingsView(
                settings: model.protectionSettings,
                catalog: model.applicationCatalog,
                launchAtLogin: model.launchAtLogin,
                hasFaceProfile: model.hasProfile,
                onRequestEnrollment: {
                    enrollAfterSettingsDismiss = true
                    model.isProtectionSettingsPresented = false
                },
                onConfigurationChanged: model.protectionConfigurationDidChange
            )
        }
        .alert("Glance Unlock", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert("Reset face profile?", isPresented: $confirmingProfileReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Profile", role: .destructive) { resetProfile() }
        } message: {
            Text("This permanently removes the enrolled face representations from this Mac. You can enrol again at any time.")
        }
    }

    private var ambientBackground: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.accent.opacity(0.08))
                .frame(width: 540, height: 540)
                .blur(radius: 120)
                .offset(x: 360, y: -240)
            LinearGradient(
                colors: [.white.opacity(0.018), .clear, .black.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack {
            AppMark()
            Spacer()
            Button {
                model.isProtectionSettingsPresented = true
            } label: {
                Label("Protected apps", systemImage: "square.grid.2x2")
            }
            .buttonStyle(GlanceSecondaryButtonStyle())
            PrivacyBadge(text: "On-device only")
        }
        .padding(.horizontal, 36)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusLine
                .padding(.bottom, 22)

            Text(model.hasProfile ? "Private apps,\none glance away." : "Your face stays\non this Mac.")
                .font(.system(size: 46, weight: .medium, design: .monospaced))
                .tracking(-2.3)
                .foregroundStyle(DesignSystem.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(model.hasProfile
                 ? "Choose which apps Glance should cover. Open them with face and blink verification, or use the Mac’s Touch ID and password fallback."
                 : "Create a private profile from five guided samples. Only derived face representations are stored securely.")
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundStyle(DesignSystem.secondaryText)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

            Button {
                if model.hasProfile {
                    model.isProtectionSettingsPresented = true
                } else {
                    showingEnrollment = true
                }
            } label: {
                HStack {
                    Text(model.hasProfile ? "MANAGE PROTECTED APPS" : "SET UP FACE PROFILE")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(GlancePrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
            .padding(.top, 30)

            if model.hasProfile {
                HStack(spacing: 10) {
                    Button("TRY FACE CHECK") { model.isSafeLockPresented = true }
                        .buttonStyle(GlanceSecondaryButtonStyle())

                    Button("RE-ENROL") { showingEnrollment = true }
                        .buttonStyle(GlanceSecondaryButtonStyle())

                    Button("RESET PROFILE", role: .destructive) { confirmingProfileReset = true }
                        .buttonStyle(GlanceDestructiveButtonStyle())

                    Spacer(minLength: 0)

                    #if DEBUG
                    Button("TUNE") { showingDeveloperTuning = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.tertiaryText)
                    #endif
                }
                .padding(.top, 12)
            }
        }
    }

    private var statusLine: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(model.hasProfile ? DesignSystem.success : DesignSystem.warning)
                .frame(width: 7, height: 7)
                .shadow(color: (model.hasProfile ? DesignSystem.success : DesignSystem.warning).opacity(0.5), radius: 5)
            Text(model.hasProfile ? "FACE PROFILE READY" : "SETUP REQUIRED")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(DesignSystem.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
            Text("APP PROTECTION WORKS WHILE GLANCE IS RUNNING — MACOS LOGIN IS UNCHANGED")
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .tracking(0.6)
        .foregroundStyle(DesignSystem.tertiaryText)
        .padding(.bottom, 24)
        .accessibilityElement(children: .combine)
    }

    private func resetProfile() {
        do {
            try model.profileStore.delete()
            model.refreshProfile()
        } catch {
            model.errorMessage = "The face profile could not be removed. Try again after opening your Mac normally."
        }
    }
}

private struct SecurityVisual: View {
    let hasProfile: Bool
    let reduceMotion: Bool
    var compact = false
    @State private var orbiting = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.stroke, lineWidth: 1)
            Circle()
                .trim(from: 0.05, to: hasProfile ? 0.82 : 0.30)
                .stroke(
                    hasProfile ? DesignSystem.success : DesignSystem.accent,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(orbiting ? 360 : 0))
                .shadow(color: (hasProfile ? DesignSystem.success : DesignSystem.accent).opacity(0.30), radius: 12)

            Circle()
                .fill(Color.black.opacity(0.54))
                .padding(compact ? 20 : 34)
                .overlay {
                    Circle()
                        .stroke(DesignSystem.strokeStrong, lineWidth: 1)
                        .padding(compact ? 20 : 34)
                }

            VStack(spacing: compact ? 5 : 12) {
                Image("GlanceLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 48 : 84, height: compact ? 48 : 84)
                Text(hasProfile ? "IDENTITY / LOCAL" : "AWAITING / PROFILE")
                    .font(.system(size: compact ? 8 : 10, weight: .semibold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(DesignSystem.secondaryText)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(compact ? 4 : 22)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                orbiting = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasProfile ? "Face profile ready" : "Face profile setup required")
    }
}
