import AppKit
import SwiftUI

struct CameraPermissionView: View {
    let permission: CameraPermission
    let request: () -> Void

    var body: some View {
        ZStack {
            DesignSystem.background.ignoresSafeArea()
            Circle()
                .fill(DesignSystem.accent.opacity(0.09))
                .frame(width: 420, height: 420)
                .blur(radius: 100)

            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(DesignSystem.surfaceStrong)
                    Circle().stroke(DesignSystem.strokeStrong, lineWidth: 1)
                    Image(systemName: permission == .notDetermined ? "camera.fill" : "camera.slash.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(DesignSystem.accent)
                }
                .frame(width: 76, height: 76)

                Text(permission == .notDetermined ? "CAMERA ACCESS" : "CAMERA IS OFF")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.secondaryText)
                    .padding(.top, 24)

                Text(permission == .notDetermined ? "See you.\nSave nothing." : "One permission\nneeds your attention.")
                    .font(.system(size: 30, weight: .medium, design: .monospaced))
                    .tracking(-1.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignSystem.primaryText)
                    .padding(.top, 13)

                Text(permission == .notDetermined
                     ? "Glance uses the camera to find your face. Frames stay in memory and no photo or video is saved."
                     : "Enable camera access for Glance Unlock in System Settings, then return here to continue.")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignSystem.secondaryText)
                    .frame(maxWidth: 430)
                    .padding(.top, 16)

                Group {
                    if permission == .notDetermined {
                        Button("ALLOW CAMERA ACCESS", action: request)
                    } else {
                        Button("OPEN PRIVACY SETTINGS") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                .buttonStyle(GlancePrimaryButtonStyle())
                .frame(width: 330)
                .padding(.top, 28)

                PrivacyBadge(text: "On-device processing")
                    .padding(.top, 16)
            }
            .padding(44)
            .frame(maxWidth: 560)
            .glassPanel(cornerRadius: 30)
        }
        .glanceTypography()
    }
}
