import SwiftUI

struct TaskRowView: View {
    let task: TaskEntry
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    // Status indicator
                    Image(systemName: task.completedOnTime ? "checkmark.circle.fill" : "clock.badge.exclamationmark.fill")
                        .foregroundStyle(task.completedOnTime ? .green : .orange)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.label)
                            .font(.body)
                            .foregroundStyle(.primary)

                        HStack(spacing: 6) {
                            if let actual = task.actualDuration {
                                Text(actual.shortFormatted)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if task.isOverTime, let actual = task.actualDuration {
                                let over = actual - task.estimatedDuration
                                Text(over.overtimeFormatted)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    Spacer()

                    // Tag badge
                    if let tag = task.tag {
                        Text(tag.name)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: tag.colorHex).opacity(0.2))
                            .foregroundStyle(Color(hex: tag.colorHex))
                            .clipShape(Capsule())
                    }

                    // Expand chevron (only if updates exist)
                    if !task.updates.isEmpty {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded updates
            if expanded && !task.updates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(task.updates.sorted(by: { $0.createdAt < $1.createdAt })) { update in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(update.createdAt.shortTimeString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(update.note)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
                .padding(.leading, 36)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
