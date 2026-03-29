import SwiftUI

struct DurationPickerView: View {
    @Binding var duration: TimeInterval  // stored in seconds

    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 5

    private let hours   = Array(0...23)
    private let minutes = Array(0...59)

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: $selectedHours) {
                ForEach(hours, id: \.self) { h in
                    Text("\(h)h").tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("Minutes", selection: $selectedMinutes) {
                ForEach(minutes, id: \.self) { m in
                    Text("\(m)m").tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(height: 120)
        .onChange(of: selectedHours)   { _, _ in updateDuration() }
        .onChange(of: selectedMinutes) { _, _ in updateDuration() }
        .onAppear { syncFromDuration() }
    }

    private func updateDuration() {
        duration = TimeInterval(selectedHours * 3600 + selectedMinutes * 60)
    }

    private func syncFromDuration() {
        let total = Int(duration)
        selectedHours   = total / 3600
        selectedMinutes = (total % 3600) / 60
    }
}
