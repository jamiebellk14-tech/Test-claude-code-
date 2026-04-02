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
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily screen time limit")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                Text("\(hoursTarget)")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(green)
                                Text("hours")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            Text(":")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.secondary)

                            VStack(spacing: 4) {
                                Text("\(minutesTarget < 10 ? "0" : "")\(minutesTarget)")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(green)
                                Text("minutes")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 8)

                        Stepper("Hours: \(hoursTarget)", value: $hoursTarget, in: 0...16)
                            .labelsHidden()
                        Stepper("Minutes: \(minutesTarget)", value: $minutesTarget, in: 0...55, step: 5)
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Screen Time Goal")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(pickupsTarget) pickups")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(green)
                        }
                        Stepper("", value: $pickupsTarget, in: 5...200, step: 5)
                            .labelsHidden()
                    }
                } header: {
                    Text("Daily Pickups Goal")
                } footer: {
                    Text("Average is around 80–100 pickups per day. Start with a realistic goal and reduce over time.")
                }

                if vm.streak > 0 {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(green)
                            Text("You have a \(vm.streak)-day streak — lowering your goal won't reset it.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button("Save Goal") { save() }
                        .buttonStyle(TactileButtonStyle())
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }
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
