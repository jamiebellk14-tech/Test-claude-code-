import SwiftUI
import Charts

struct TagBarChartView: View {
    let stats: [TagStat]

    var body: some View {
        Chart(stats) { stat in
            BarMark(
                x: .value("Tag", stat.name),
                y: .value("Tasks", stat.taskCount)
            )
            .foregroundStyle(Color(hex: stat.colorHex))
            .cornerRadius(4)
            .annotation(position: .top, alignment: .center) {
                Text("\(stat.taskCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
        }
        .frame(height: 160)
    }
}
