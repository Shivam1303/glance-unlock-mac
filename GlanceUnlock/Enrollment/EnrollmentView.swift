import SwiftUI

struct EnrollmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: EnrollmentViewModel
    @ObservedObject private var camera: CameraService

    init(camera: CameraService, store: FaceProfileStore, featurePrintService: FeaturePrintService) {
        _viewModel = StateObject(
            wrappedValue: EnrollmentViewModel(
                camera: camera,
                store: store,
                featurePrintService: featurePrintService
            )
        )
        _camera = ObservedObject(wrappedValue: camera)
    }

    var body: some View {
        Group {
            if camera.permission == .authorized {
                enrolmentWorkspace
            } else {
                CameraPermissionView(permission: camera.permission, request: viewModel.start)
            }
        }
        .frame(minWidth: 860, idealWidth: 1040, minHeight: 640, idealHeight: 700)
        .background(DesignSystem.background)
        .glanceTypography()
        .onAppear {
            camera.refreshPermission()
            if camera.permission == .authorized { viewModel.start() }
        }
        .onDisappear { viewModel.stop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if camera.permission == .authorized, !viewModel.isComplete { viewModel.start() }
            case .inactive, .background:
                viewModel.stop()
            @unknown default:
                viewModel.stop()
            }
        }
        .alert("Face enrolment", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var enrolmentWorkspace: some View {
        VStack(spacing: 0) {
            header

            HStack(spacing: 28) {
                enrolmentBrief
                    .frame(width: 300)
                cameraCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
    }

    private var header: some View {
        HStack {
            AppMark(compact: true)
            Rectangle()
                .fill(DesignSystem.stroke)
                .frame(width: 1, height: 18)
            Text("Face enrolment")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignSystem.secondaryText)
            Spacer()
            Button("Cancel") {
                viewModel.stop()
                dismiss()
            }
            .buttonStyle(GlanceSecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var enrolmentBrief: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isComplete ? DesignSystem.success : DesignSystem.accent)
                    .frame(width: 6, height: 6)
                Text(viewModel.isComplete ? "Profile ready" : "Guided capture")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.secondaryText)
            }

            Text(viewModel.isComplete ? "That’s you,\nsecured locally." : "Five looks.\nOne private profile.")
                .font(.system(size: 29, weight: .medium, design: .monospaced))
                .tracking(-1.5)
                .foregroundStyle(DesignSystem.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 17)

            Text(viewModel.isComplete
                 ? "Your derived face representations are now stored in this Mac’s Keychain."
                 : "Samples capture automatically. Follow each direction and hold still for a moment.")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(DesignSystem.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            progress
                .padding(.top, 25)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(stepTitles.enumerated()), id: \.offset) { index, title in
                    EnrollmentStepRow(
                        number: index + 1,
                        title: title,
                        isComplete: index < viewModel.sampleCount,
                        isCurrent: index == viewModel.sampleCount && !viewModel.isComplete
                    )
                }
            }
            .padding(.top, 18)

            Spacer(minLength: 16)

            Label("No camera image is saved", systemImage: "lock.fill")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignSystem.tertiaryText)

            if viewModel.isComplete {
                Button {
                    viewModel.stop()
                    dismiss()
                } label: {
                    HStack {
                        Text("Done")
                        Spacer()
                        Image(systemName: "checkmark")
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(GlancePrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .padding(.top, 18)
            }
        }
        .padding(24)
        .glassPanel()
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .lastTextBaseline) {
                Text(String(format: "%02d", viewModel.sampleCount))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.primaryText)
                    .contentTransition(.numericText())
                Text("of 05 samples")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.tertiaryText)
                Spacer()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(viewModel.isComplete ? DesignSystem.success : DesignSystem.accent)
                        .frame(width: proxy.size.width * CGFloat(viewModel.sampleCount) / CGFloat(viewModel.requiredSamples))
                }
            }
            .frame(height: 3)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78), value: viewModel.sampleCount)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.sampleCount) of \(viewModel.requiredSamples) samples captured")
    }

    private var cameraCard: some View {
        Group {
            if viewModel.isComplete {
                completionPanel
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                liveCameraPanel
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 12)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.30), value: viewModel.isComplete)
        .accessibilityElement(children: .contain)
    }

    private var liveCameraPanel: some View {
        ZStack {
            CameraPreview(session: viewModel.camera.session)
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.42), .clear, .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            VStack(spacing: 0) {
                captureHeader
                    .padding(18)

                Spacer()

                FaceGuide(
                    tint: statusTint,
                    isFaceReady: viewModel.guidance == .valid,
                    captureEvent: viewModel.captureEvent,
                    reduceMotion: reduceMotion
                )
                .frame(width: 184, height: 232)

                Spacer()

                cameraGuidance
                    .padding(18)
            }
        }
    }

    private var captureHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Circle()
                    .fill(camera.hasReceivedFrame ? DesignSystem.success : DesignSystem.warning)
                    .frame(width: 6, height: 6)
                Text(camera.hasReceivedFrame ? "Camera live" : "Starting camera")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.82))
            }

            Spacer(minLength: 12)

            Text("\(viewModel.sampleCount + 1) of \(viewModel.requiredSamples)  ·  \(viewModel.poseInstruction)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Color.black.opacity(0.54), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var completionPanel: some View {
        ZStack {
            DesignSystem.backgroundRaised

            Circle()
                .fill(DesignSystem.success.opacity(0.10))
                .frame(width: 360, height: 360)
                .blur(radius: 70)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.success.opacity(0.10))
                    Circle()
                        .stroke(DesignSystem.success.opacity(0.28), lineWidth: 1)
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(DesignSystem.success)
                }
                .frame(width: 76, height: 76)

                Text("Capture complete")
                    .font(.system(size: 26, weight: .medium, design: .monospaced))
                    .tracking(-1.0)
                    .foregroundStyle(DesignSystem.primaryText)
                    .padding(.top, 24)

                Text("Five face representations are secured\nin this Mac’s Keychain.")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignSystem.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 12)

                HStack(spacing: 7) {
                    ForEach(0..<viewModel.requiredSamples, id: \.self) { _ in
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.78))
                            .frame(width: 20, height: 20)
                            .background(DesignSystem.success, in: Circle())
                    }
                }
                .padding(.top, 22)
                .accessibilityHidden(true)

                HStack(spacing: 20) {
                    Label("On-device", systemImage: "desktopcomputer")
                    Divider().frame(height: 14)
                    Label("Encrypted", systemImage: "lock.fill")
                    Divider().frame(height: 14)
                    Label("No photos", systemImage: "photo.badge.xmark")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignSystem.secondaryText)
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(Color.black.opacity(0.20), in: Capsule())
                .padding(.top, 28)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Capture complete. Five face representations are secured in this Mac’s Keychain. No photos were saved.")
    }

    private var cameraGuidance: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(statusTint.opacity(0.17))
                Image(systemName: guidanceSymbol(viewModel.guidance))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .accessibilityHidden(true)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.guidance.message)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.94))
                Text(viewModel.isCapturingSample
                     ? "Creating a private representation…"
                     : helperText(for: viewModel.guidance, cameraHasFrames: camera.hasReceivedFrame))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.54))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var stepTitles: [String] {
        ["Look straight", "Turn slightly left", "Turn slightly right", "Relax your expression", "Final forward look"]
    }

    private var statusTint: Color {
        if viewModel.isComplete { return DesignSystem.success }
        switch viewModel.guidance {
        case .valid: return DesignSystem.success
        case .multipleFaces, .poorQuality: return DesignSystem.warning
        default: return DesignSystem.accent
        }
    }

    private func guidanceSymbol(_ guidance: FaceGuidance) -> String {
        switch guidance {
        case .valid: "checkmark"
        case .multipleFaces: "person.2.fill"
        case .poorQuality: "camera.aperture"
        case .tooSmall: "arrow.up.left.and.arrow.down.right"
        case .offCenter: "viewfinder"
        case .noFace: "face.dashed"
        }
    }

    private func helperText(for guidance: FaceGuidance, cameraHasFrames: Bool) -> String {
        switch guidance {
        case .valid: "Hold still. Capture happens automatically."
        case .multipleFaces: "Keep only one person in view."
        case .tooSmall: "Move a little closer to the display."
        case .offCenter: "Move your face toward the centre guide."
        case .poorQuality: "Use even lighting and hold still."
        case .noFace: cameraHasFrames ? "Look toward the camera above the display." : "Starting the camera…"
        }
    }
}

private struct EnrollmentStepRow: View {
    let number: Int
    let title: String
    let isComplete: Bool
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(isComplete ? DesignSystem.success : isCurrent ? DesignSystem.accent : Color.white.opacity(0.07))
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.84))
                } else {
                    Text(String(format: "%02d", number))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(isCurrent ? Color.black.opacity(0.84) : DesignSystem.tertiaryText)
                }
            }
            .frame(width: 22, height: 22)

            Text(title)
                .font(.system(size: 10, weight: isCurrent ? .semibold : .medium, design: .monospaced))
                .foregroundStyle(isComplete || isCurrent ? DesignSystem.primaryText.opacity(0.88) : DesignSystem.tertiaryText)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(number): \(title), \(isComplete ? "complete" : isCurrent ? "current" : "upcoming")")
    }
}

private struct FaceGuide: View {
    let tint: Color
    let isFaceReady: Bool
    let captureEvent: Int
    let reduceMotion: Bool
    @State private var flash = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 70, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                .padding(10)

            FaceTargetShape()
                .stroke(tint, style: StrokeStyle(lineWidth: isFaceReady ? 2.5 : 1.5, lineCap: .round, lineJoin: .round))
                .shadow(color: tint.opacity(isFaceReady ? 0.42 : 0.14), radius: isFaceReady ? 10 : 4)
                .scaleEffect(flash ? 1.035 : 1)

            VStack(spacing: 7) {
                Image(systemName: isFaceReady ? "checkmark" : "faceid")
                    .font(.system(size: isFaceReady ? 14 : 24, weight: .light))
                Text(isFaceReady ? "Hold still" : "Centre your face")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(Color.white.opacity(isFaceReady ? 0.90 : 0.58))
        }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.72), value: isFaceReady)
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.62), value: flash)
        .onChange(of: captureEvent) { _, _ in
            guard !reduceMotion else { return }
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { flash = false }
        }
        .accessibilityHidden(true)
    }
}

/// Four quiet corners provide alignment without placing a heavy ring over the
/// user's face or competing with the live camera image.
private struct FaceTargetShape: Shape {
    func path(in rect: CGRect) -> Path {
        let corner: CGFloat = min(34, rect.width * 0.18)
        let radius: CGFloat = 17
        var path = Path()

        path.move(to: CGPoint(x: 0, y: corner))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
        path.addLine(to: CGPoint(x: corner, y: 0))

        path.move(to: CGPoint(x: rect.maxX - corner, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: radius),
            control: CGPoint(x: rect.maxX, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: corner))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))

        path.move(to: CGPoint(x: corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - radius),
            control: CGPoint(x: 0, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: 0, y: rect.maxY - corner))

        return path
    }
}
