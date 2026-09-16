import SwiftUI

struct StatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: "circle.fill")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color.black.opacity(0.32), in: Capsule())
            .overlay { Capsule().stroke(tint.opacity(0.22), lineWidth: 1) }
    }
}
