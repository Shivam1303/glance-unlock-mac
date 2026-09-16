import SwiftUI

#if DEBUG
struct DeveloperTuningView: View {
    @AppStorage("matchDistanceThreshold") private var threshold = 12.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DEVELOPER / MATCH POLICY")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(DesignSystem.secondaryText)
            HStack(alignment: .lastTextBaseline) {
                Text("DISTANCE")
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                Spacer()
                Text("\(threshold, specifier: "%.1f")")
                    .font(.system(size: 26, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            }
            .padding(.top, 18)
            Slider(value: $threshold, in: 1...30, step: 0.5)
                .tint(DesignSystem.accent)
                .padding(.top, 15)
            Text("A lower value is more conservative. This preference contains no face data.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DesignSystem.secondaryText)
                .lineSpacing(3)
                .padding(.top, 14)
        }
        .padding(26)
        .frame(width: 390)
        .background(DesignSystem.backgroundRaised)
        .glanceTypography()
    }
}
#endif
