import AppKit
import LocalAuthentication
import SwiftUI

struct AppUnlockGateView: View {
    let applicationName: String
    let applicationIcon: NSImage
    let onAuthenticated: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: UnlockViewModel
    @State private var isUsingSystemAuthentication = false
    @State private var systemAuthenticationError: String?
    @State private var authenticationContext: LAContext?
    @State private var didComplete = false

    init(
        applicationName: String,
        applicationIcon: NSImage,
        camera: CameraService,
        store: FaceProfileStore,
        featurePrintService: FeaturePrintService,
        onAuthenticated: @escaping @MainActor () -> Void
    ) {
        self.applicationName = applicationName
        self.applicationIcon = applicationIcon
        self.onAuthenticated = onAuthenticated
        _viewModel = StateObject(
            wrappedValue: UnlockViewModel(
                camera: camera,
                store: store,
                featurePrintService: featurePrintService
            )
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            gateBackground

            VStack(spacing: 0) {
                HStack {
                    AppMark(compact: true).opacity(0.72)
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)

                Spacer()

                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        Image(nsImage: applicationIcon)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .padding(17)
                    }
                    .frame(width: 86, height: 86)

                    Text(applicationName)
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .tracking(-1.2)
                        .foregroundStyle(DesignSystem.primaryText)
                        .padding(.top, 24)

                    Text("Glance is protecting this app")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(DesignSystem.secondaryText)
                        .padding(.top, 8)

                    faceStatus
                        .padding(.top, 26)

                    VStack(spacing: 10) {
                        Button(action: authenticateWithSystem) {
                            HStack {
                                if isUsingSystemAuthentication {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "touchid")
                                        .font(.system(size: 18, weight: .medium))
                                        .accessibilityHidden(true)
                                }
                                Text(isUsingSystemAuthentication ? "Waiting for macOS…" : "Use Touch ID or Password")
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(GlancePrimaryButtonStyle())
                        .disabled(isUsingSystemAuthentication || viewModel.unlocked)

                        Text("Uses Apple’s secure authentication dialog. Password, Touch ID, and Apple Watch remain available when supported.")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(DesignSystem.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .frame(width: 430)
                    .padding(.top, 24)

                    if let systemAuthenticationError {
                        Label(systemAuthenticationError, systemImage: "exclamationmark.circle")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignSystem.danger)
                            .padding(.top, 14)
                            .accessibilityLabel("Authentication error: \(systemAuthenticationError)")
                    }
                }

                Spacer()

                Text("Authentication required · app privacy layer · macOS login is unchanged")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.tertiaryText)
                    .padding(.bottom, 26)
            }

            CameraNotchView(
                title: notchTitle,
                detail: notchDetail,
                symbol: notchSymbol,
                tint: stateTint,
                eventID: stateEvent,
                isActive: !viewModel.unlocked && !isUsingSystemAuthentication,
                style: .screenEdge
            )
            .ignoresSafeArea(edges: .top)
        }
        .glanceTypography()
        .onAppear { viewModel.start() }
        .onChange(of: viewModel.unlocked) { _, unlocked in
            guard unlocked else { return }
            finishAuthentication()
        }
        .onDisappear {
            authenticationContext?.invalidate()
            viewModel.stop()
        }
    }

    private var gateBackground: some View {
        ZStack {
            DesignSystem.background
            RadialGradient(
                colors: [stateTint.opacity(0.10), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 430
            )
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: viewModel.state)
        .accessibilityHidden(true)
    }

    private var faceStatus: some View {
        HStack(spacing: 9) {
            Image(systemName: notchSymbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(stateTint)
                .accessibilityHidden(true)
            Text(notchDetail)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignSystem.secondaryText)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay { Capsule().stroke(Color.white.opacity(0.09), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    private var stateTint: Color {
        switch viewModel.state {
        case .unlocked: DesignSystem.success
        case .notRecognized: DesignSystem.danger
        case .blinkOnce: DesignSystem.warning
        default: DesignSystem.accent
        }
    }

    private var notchTitle: String {
        switch viewModel.state {
        case .unlocked: "App unlocked"
        case .notRecognized: "Face not recognized"
        default: "Unlock \(applicationName)"
        }
    }

    private var notchDetail: String {
        if isUsingSystemAuthentication { return "Complete the macOS authentication prompt" }
        switch viewModel.state {
        case .lookingForFace: return "Look toward the camera"
        case .faceFound: return "Identity located · hold still"
        case .blinkOnce: return viewModel.blinkInstruction
        case .checking: return "Matching securely on this Mac"
        case .unlocked: return "Face and liveness verified"
        case .notRecognized: return viewModel.diagnostics ?? "Try again or use macOS authentication"
        }
    }

    private var notchSymbol: String {
        if isUsingSystemAuthentication { return "touchid" }
        switch viewModel.state {
        case .lookingForFace: return "face.dashed"
        case .faceFound, .checking: return "faceid"
        case .blinkOnce: return "eye.fill"
        case .unlocked: return "checkmark"
        case .notRecognized: return "exclamationmark"
        }
    }

    private var stateEvent: Int {
        if isUsingSystemAuthentication { return 6 }
        switch viewModel.state {
        case .lookingForFace: return 0
        case .faceFound: return 1
        case .blinkOnce: return 2
        case .checking: return 3
        case .unlocked: return 4
        case .notRecognized: return 5
        }
    }

    private func authenticateWithSystem() {
        guard !isUsingSystemAuthentication else { return }
        systemAuthenticationError = nil
        isUsingSystemAuthentication = true
        viewModel.stop()

        let context = LAContext()
        context.localizedCancelTitle = "Return to locked app"
        authenticationContext = context

        Task { @MainActor in
            do {
                try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Open \(applicationName)"
                )
                authenticationContext = nil
                isUsingSystemAuthentication = false
                finishAuthentication()
            } catch let error as LAError {
                authenticationContext = nil
                isUsingSystemAuthentication = false
                if error.code != .userCancel && error.code != .systemCancel && error.code != .appCancel {
                    systemAuthenticationError = error.localizedDescription
                }
                viewModel.start()
            } catch {
                authenticationContext = nil
                isUsingSystemAuthentication = false
                systemAuthenticationError = error.localizedDescription
                viewModel.start()
            }
        }
    }

    private func finishAuthentication() {
        guard !didComplete else { return }
        didComplete = true
        authenticationContext?.invalidate()
        viewModel.stop()
        onAuthenticated()
    }
}
