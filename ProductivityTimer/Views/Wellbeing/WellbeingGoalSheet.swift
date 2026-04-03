import SwiftUI
import SwiftData

private let green = Color(hex: "#00bf63")

struct WellbeingGoalSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var vm: WellbeingViewModel

    @State private var hoursTarget: Int = 2
    @State private var minutesTarget: Int = 0
    @State private var pickupsTarget: Int = 40

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Screen Time Goal Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Daily screen time limit")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        // HH : MM display
                        HStack(spacing: 0) {
                            // Hours
                            VStack(spacing: 6) {
                                HStack(spacing: 12) {
                                    stepButton(icon: "minus", action: { hoursTarget = max(0, hoursTarget - 1) })
                                    VStack(spacing: 2) {
                                        Text("\(hoursTarget)")
                                            .font(.system(size: 40, weight: .bold, design: .rounded))
                                            .foregroundStyle(green)
                                            .frame(minWidth: 48)
                                        Text("hours")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    stepButton(icon: "plus", action: { hoursTarget = min(16, hoursTarget + 1) })
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Text(":")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(Color(.tertiaryLabel))
                                .padding(.bottom, 18)

                            // Minutes
                            VStack(spacing: 6) {
                                HStack(spacing: 12) {
                                    stepButton(icon: "minus", action: { minutesTarget = max(0, minutesTarget - 5) })
                                    VStack(spacing: 2) {
                                        Text(minutesTarget < 10 ? "0\(minutesTarget)" : "\(minutesTarget)")
                                            .font(.system(size: 40, weight: .bold, design: .rounded))
                                            .foregroundStyle(green)
                                            .frame(minWidth: 48)
                                        Text("minutes")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    stepButton(icon: "plus", action: { minutesTarget = min(55, minutesTarget + 5) })
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 4)

                        Text("Recommended: 2h or less per day")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(.separator).opacity(0.4), lineWidth: 1))

                    // Pickups Goal Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Daily pickups limit")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack {
                            stepButton(icon: "minus", action: { pickupsTarget = max(5, pickupsTarget - 5) })
                            Spacer()
                            VStack(spacing: 2) {
                                Text("\(pickupsTarget)")
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundStyle(green)
                                Text("pickups / day")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            stepButton(icon: "plus", action: { pickupsTarget = min(200, pickupsTarget + 5) })
                        }
                        .padding(.vertical, 4)

                        Text("Average is 80–100 pickups/day. Start realistic and reduce over time.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(.separator).opacity(0.4), lineWidth: 1))

                    // Streak warning (if active)
                    if vm.streak > 0 {
                        HStack(spacing: 10) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                            Text("You have a \(vm.streak)-day streak — lowering your goal won't reset it.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.9))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14).fill(green)
                                RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                                LinearGradient(
                                    colors: [Color.white.opacity(0.10), Color.clear],
                                    startPoint: .top, endPoint: .center
                                ).clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }

                    // Save button
                    Button("Save Goal") { save() }
                        .buttonStyle(TactileButtonStyle())
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .navigationTitle("Wellbeing Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(green)
                }
            }
            .onAppear { loadCurrent() }
        }
    }

    @ViewBuilder
    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(green)
                .frame(width: 36, height: 36)
                .background {
                    ZStack {
                        Circle().fill(green.opacity(0.12))
                        Circle().strokeBorder(green.opacity(0.25), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func loadCurrent() {
        guard let goal = vm.goal else { return }
        hoursTarget = goal.dailyPhoneMinutesTarget / 60
        minutesTarget = goal.dailyPhoneMinutesTarget % 60
        pickupsTarget = goal.dailyPickupsTarget
    }

    private func save() {
        guard let goal = vm.goal else { return }
        goal.dailyPhoneMinutesTarget = hoursTarget * 60 + minutesTarget
        goal.dailyPickupsTarget = pickupsTarget
        try? context.save()
        vm.load(context: context)
        dismiss()
    }
}
