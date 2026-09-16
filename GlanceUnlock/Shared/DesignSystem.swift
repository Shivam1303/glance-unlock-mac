import SwiftUI

enum DesignSystem {
    // Quiet, semantic colors keep the interface close to macOS while the cool
    // blue is reserved for the single action or state that needs attention.
    static let background = Color(red: 0.025, green: 0.028, blue: 0.035)
    static let backgroundRaised = Color(red: 0.055, green: 0.060, blue: 0.072)
    static let surface = Color.white.opacity(0.055)
    static let surfaceStrong = Color.white.opacity(0.09)
    static let stroke = Color.white.opacity(0.11)
    static let strokeStrong = Color.white.opacity(0.18)
    static let primaryText = Color.white.opacity(0.96)
    static let secondaryText = Color.white.opacity(0.58)
    // Kept above the AA contrast floor even at the smallest label sizes.
    static let tertiaryText = Color.white.opacity(0.48)
    static let accent = Color(red: 0.32, green: 0.67, blue: 1.00)
    static let success = Color(red: 0.31, green: 0.88, blue: 0.60)
    static let warning = Color(red: 1.00, green: 0.72, blue: 0.30)
    static let danger = Color(red: 1.00, green: 0.39, blue: 0.39)

    static let cornerRadius: CGFloat = 24
    static let smallCornerRadius: CGFloat = 14
}

extension View {
    /// SF Mono through SwiftUI's system design keeps the app native and lets
    /// type continue to scale with the user's macOS accessibility settings.
    func glanceTypography() -> some View {
        fontDesign(.monospaced)
    }

    func glassPanel(cornerRadius: CGFloat = DesignSystem.cornerRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DesignSystem.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(DesignSystem.stroke, lineWidth: 1)
                }
        )
    }
}

struct GlancePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.black.opacity(0.90))
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 20)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.76 : 0.96))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct GlanceSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(DesignSystem.primaryText.opacity(configuration.isPressed ? 0.62 : 0.86))
            .frame(minHeight: 44)
            .padding(.horizontal, 18)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.055))
                    .overlay { Capsule(style: .continuous).stroke(DesignSystem.stroke, lineWidth: 1) }
            )
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct GlanceDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(DesignSystem.danger.opacity(configuration.isPressed ? 0.72 : 0.95))
            .frame(minHeight: 44)
            .padding(.horizontal, 18)
            .background(
                Capsule(style: .continuous)
                    .fill(DesignSystem.danger.opacity(configuration.isPressed ? 0.13 : 0.075))
                    .overlay { Capsule(style: .continuous).stroke(DesignSystem.danger.opacity(0.25), lineWidth: 1) }
            )
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct AppMark: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 11) {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 7 : 9, style: .continuous)
                    .fill(Color.white)
                Image(systemName: "faceid")
                    .font(.system(size: compact ? 13 : 16, weight: .semibold))
                    .foregroundStyle(Color.black)
            }
            .frame(width: compact ? 28 : 34, height: compact ? 28 : 34)

            Text("GLANCE")
                .font(.system(size: compact ? 12 : 14, weight: .semibold, design: .monospaced))
                .tracking(compact ? 1.4 : 1.8)
                .foregroundStyle(DesignSystem.primaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Glance Unlock")
    }
}

struct PrivacyBadge: View {
    let text: String

    var body: some View {
        Label(text.uppercased(), systemImage: "lock.fill")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(DesignSystem.secondaryText)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(Color.white.opacity(0.045), in: Capsule())
            .overlay { Capsule().stroke(DesignSystem.stroke, lineWidth: 1) }
    }
}
