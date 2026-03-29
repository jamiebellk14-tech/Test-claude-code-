import SwiftUI
import SwiftData

struct ActiveTimerView: View {
    let timerViewModel: TimerViewModel

    @Environment(\.modelContext) private var context
    @State private var showEndConfirmation = false

    private var task: TaskEntry? { timerViewModel.currentTask }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

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
                            .padding(.horizontal)
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

                Spacer()

                // End button
                Button(role: .destructive) {
                    showEndConfirmation = true
                } label: {
                    Label("End Task", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationTitle("Timer Running")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("End this task?", isPresented: $showEndConfirmation) {
                Button("End Task", role: .destructive) {
                    timerViewModel.endTask(context: context)
                }
                Button("Keep Going", role: .cancel) {}
            }
        }
    }
}
