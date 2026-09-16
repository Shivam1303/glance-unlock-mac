import SwiftUI

struct PrototypeLockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: UnlockViewModel

    init(camera: CameraService, store: FaceProfileStore, featurePrintService: FeaturePrintService) {
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
            LockScreenBackground(state: viewModel.state)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 9) {
                        Text(context.date, format: .dateTime.hour().minute())
                            .font(.system(size: 94, weight: .ultraLight, design: .monospaced))
                            .tracking(-7)
                            .monospacedDigit()
                            .foregroundStyle(DesignSystem.primaryText)
                        Text(context.date, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(DesignSystem.secondaryText)
                    }
                }
                .padding(.top, 72)

                Spacer()

                lockState

                Spacer()

                bottomPrompt
                    .padding(.bottom, 28)
            }

            CameraNotchView(
                title: viewModel.state.message,
                detail: notchDetail(for: viewModel),
                symbol: notchSymbol(viewModel.state),
                tint: stateTint,
                eventID: stateEvent(viewModel.state),
                isActive: !viewModel.unlocked,
                style: .screenEdge
            )
            .ignoresSafeArea(edges: .top)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .glanceTypography()
        .onAppear {
            viewModel.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
        }
        .onChange(of: viewModel.unlocked) { _, isUnlocked in
            guard isUnlocked else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
        }
        .onDisappear {
            viewModel.stop()
            if NSApp.keyWindow?.styleMask.contains(.fullScreen) == true {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
        }
    }

    private var topBar: some View {
        HStack {
            AppMark(compact: true)
                .opacity(0.62)
            Spacer()
            Button {
                viewModel.stop()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text("EXIT SAFE LOCK")
                    Image(systemName: "xmark")
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(GlanceSecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)
            .accessibilityHint("Returns to the Glance Unlock home screen")
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
    }

    private var lockState: some View {
        VStack(spacing: 17) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.20))
                    .frame(width: 88, height: 88)
                Circle()
                    .stroke(stateTint.opacity(0.25), lineWidth: 1)
                    .frame(width: 88, height: 88)
                Image(systemName: viewModel.unlocked ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 29, weight: .light))
                    .foregroundStyle(viewModel.unlocked ? DesignSystem.success : DesignSystem.primaryText)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(viewModel.unlocked && !reduceMotion ? 1.08 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.62), value: viewModel.unlocked)

            VStack(spacing: 6) {
                Text(viewModel.unlocked ? "ACCESS CONFIRMED" : "GLANCE SAFE LOCK")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(DesignSystem.primaryText)
                Text(viewModel.unlocked ? "Welcome back" : "Look toward the camera above")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignSystem.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.unlocked ? "Access confirmed" : "Safe lock active. Look toward the camera above.")
    }

    private var bottomPrompt: some View {
        VStack(spacing: 13) {
            Image(systemName: viewModel.unlocked ? "checkmark" : "chevron.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(viewModel.unlocked ? DesignSystem.success : DesignSystem.secondaryText)
            Text(viewModel.unlocked ? "UNLOCKING" : "FACE + BLINK REQUIRED")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.3)
                .foregroundStyle(DesignSystem.tertiaryText)
            Text("LOCAL DEMO · MACOS REMAINS UNLOCKED")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(DesignSystem.tertiaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.unlocked ? "Unlocking" : "Face and blink required")
    }

    private var stateTint: Color {
        switch viewModel.state {
        case .unlocked: DesignSystem.success
        case .notRecognized: DesignSystem.danger
        case .blinkOnce: DesignSystem.warning
        default: DesignSystem.accent
        }
    }

    private func notchDetail(for viewModel: UnlockViewModel) -> String {
        switch viewModel.state {
        case .lookingForFace: "Look toward the camera"
        case .faceFound: "Identity located · hold still"
        case .blinkOnce: viewModel.blinkInstruction
        case .checking: "Matching securely on this Mac"
        case .unlocked: "Face and liveness verified"
        case .notRecognized: "Re-center your face to retry"
        }
    }

    private func notchSymbol(_ state: UnlockState) -> String {
        switch state {
        case .lookingForFace: "face.dashed"
        case .faceFound, .checking: "faceid"
        case .blinkOnce: "eye.fill"
        case .unlocked: "checkmark"
        case .notRecognized: "exclamationmark"
        }
    }

    private func stateEvent(_ state: UnlockState) -> Int {
        switch state {
        case .lookingForFace: 0
        case .faceFound: 1
        case .blinkOnce: 2
        case .checking: 3
        case .unlocked: 4
        case .notRecognized: 5
        }
    }
}

private struct LockScreenBackground: View {
    let state: UnlockState

    private var glow: Color {
        switch state {
        case .unlocked: DesignSystem.success
        case .notRecognized: DesignSystem.danger
        case .blinkOnce: DesignSystem.warning
        default: DesignSystem.accent
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.040, blue: 0.052),
                    Color(red: 0.018, green: 0.020, blue: 0.027)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(glow.opacity(0.09))
                .frame(width: 720, height: 720)
                .blur(radius: 145)
                .offset(y: 160)
                .animation(.easeInOut(duration: 0.35), value: state)
            LinearGradient(
                colors: [.white.opacity(0.025), .clear, .black.opacity(0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .accessibilityHidden(true)
    }
}
