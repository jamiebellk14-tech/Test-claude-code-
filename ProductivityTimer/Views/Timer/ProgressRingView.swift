import SwiftUI

struct ProgressRingView: View {
    let progress: Double   // 0.0 = empty, 1.0 = full, >1.0 = overtime (turns red)
    var tagColor: Color? = nil
    var lineWidth: CGFloat = 14

    private var clampedProgress: Double { min(progress, 1.0) }
    private var isOverTime: Bool { progress > 1.0 }

    private var ringColor: Color {
        if isOverTime { return .red }
        return tagColor ?? .accentColor
    }

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: clampedProgress)

            // Overtime pulse ring (shown when over)
            if isOverTime {
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: lineWidth)
            }
        }
    }
}
