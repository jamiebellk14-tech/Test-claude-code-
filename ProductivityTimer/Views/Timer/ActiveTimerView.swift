import SwiftUI
import SwiftData

struct ActiveTimerView: View {
    let timerViewModel: TimerViewModel

    @Environment(\.modelContext) private var context

    // ── Tweak these to adjust the End Task button ──
    private let buttonCornerRadius: CGFloat      = 8
    private let buttonPaddingTop:    CGFloat     = 10
    private let buttonPaddingBottom: CGFloat     = 1
    private let buttonHorizontalPadding: CGFloat = 24
    // ──────────────────────────────────────────────

    private var task: TaskEntry? { timerViewModel.currentTask }

    var body: some View {
        NavigationStack {
            Form {
                // Timer content
                Section {
                    VStack(spacing: 32) {
                        // Task info
                        if let task {
                            VStack(spacing: 8) {
                                if let tag = task.tag {
                                    Text(tag.name)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: tag.colorHex).opacity(0.2))
                                        .foregroundStyle(Color(hex: tag.colorHex))
                                        .clipShape(Capsule())
                                }
                                Text(task.label)
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                            }
                        }

                        // Progress ring
                        ZStack {
                            ProgressRingView(progress: timerViewModel.progress)
                                .frame(width: 220, height: 220)

                            VStack(spacing: 4) {
                                Text(TimeInterval(timerViewModel.elapsedSeconds).hhmmss)
                                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                                    .foregroundStyle(timerViewModel.progress > 1 ? .red : .primary)

                                if let task {
                                    Text("of \(task.estimatedDuration.shortFormatted)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Overtime label
                        if timerViewModel.progress > 1, let task {
                            let over = TimeInterval(timerViewModel.elapsedSeconds) - task.estimatedDuration
                            Text("Over by \(over.hhmmss)")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                // End button
                Section {
                    Button {
                        timerViewModel.endTask(context: context)
                    } label: {
                        Label("End Task", systemImage: "stop.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: buttonCornerRadius)
                            .fill(Color.red)
                    )
                    .listRowInsets(EdgeInsets(
                        top: buttonPaddingTop,
                        leading: 0,
                        bottom: buttonPaddingBottom,
                        trailing: 0
                    ))
                }
            }
            .navigationTitle("Timer Running")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
