import SwiftUI

enum CameraNotchStyle {
    case floating
    case screenEdge
}

/// A camera-status surface designed to visually meet the MacBook display
/// notch. In safe lock it is attached to the screen edge; over camera content
/// it becomes a self-contained floating island.
struct CameraNotchView: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    var completedSteps: Int? = nil
    var totalSteps: Int? = nil
    var eventID = 0
    var isActive = true
    var style: CameraNotchStyle = .floating

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash = false
    @State private var scanning = false

    private var width: CGFloat { style == .screenEdge ? 410 : 420 }
    private var height: CGFloat { style == .screenEdge ? 112 : 76 }

    var body: some View {
        HStack(spacing: 14) {
            notchGlyph

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(DesignSystem.primaryText)
                    .contentTransition(.opacity)
                Text(detail)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }

            Spacer(minLength: 8)

            if let completedSteps, let totalSteps {
                progress(completed: completedSteps, total: totalSteps)
            } else {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .shadow(color: tint.opacity(0.8), radius: 5)
                    .opacity(isActive ? 1 : 0.65)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, style == .screenEdge ? 22 : 18)
        // The upper area remains visually empty where a physical MacBook notch
        // sits; status content expands directly below it like a system surface.
        .padding(.top, style == .screenEdge ? 28 : 0)
        .frame(width: width, height: height)
        .background(notchBackground)
        .scaleEffect(flash ? 1.012 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.72), value: flash)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: eventID)
        .onAppear { updateScanning() }
        .onChange(of: isActive) { _, _ in updateScanning() }
        .onChange(of: eventID) { _, _ in
            guard !reduceMotion else { return }
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { flash = false }
        }
        .accessibilityElement(children: .combine)
    }

    private var notchGlyph: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: 40, height: 40)
            Circle()
                .trim(from: 0.08, to: 0.72)
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(scanning ? 360 : 0))
                .shadow(color: tint.opacity(0.45), radius: 6)
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(tint)
                .scaleEffect(flash ? 1.12 : 1)
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var notchBackground: some View {
        if style == .screenEdge {
            ScreenEdgeNotchShape(radius: 22)
                .fill(Color.black)
                .overlay {
                    ScreenEdgeNotchShape(radius: 22)
                        .stroke(tint.opacity(flash ? 0.42 : 0.10), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.48), radius: 22, y: 12)
        } else {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.94))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(flash ? 0.55 : 0.16), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.36), radius: 18, y: 8)
        }
    }

    private func progress(completed: Int, total: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < completed ? tint : Color.white.opacity(0.16))
                    .frame(width: index < completed ? 13 : 5, height: 5)
                    .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.76), value: completed)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completed) of \(total) samples captured")
    }

    private func updateScanning() {
        guard isActive, !reduceMotion else {
            scanning = false
            return
        }
        scanning = false
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
            scanning = true
        }
    }
}

private struct ScreenEdgeNotchShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.height / 2, rect.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: r, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - r),
            control: CGPoint(x: 0, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}
