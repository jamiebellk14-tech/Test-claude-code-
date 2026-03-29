import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var allTasks: [TaskEntry]
    @Environment(\.modelContext) private var context

    @State private var timerViewModel = TimerViewModel()
    @State private var selectedTab: Int = 0
    @State private var checkInTask: TaskEntry? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Home / Active Timer
            Group {
                if timerViewModel.isRunning {
                    ActiveTimerView(timerViewModel: timerViewModel)
                } else {
                    HomeView(timerViewModel: timerViewModel)
                }
            }
            .tabItem { Label("Timer", systemImage: "timer") }
            .tag(0)

            // Tab 1: Reports
            ReportsView()
                .tabItem { Label("Reports", systemImage: "chart.bar.fill") }
                .tag(1)

            // Tab 2: Tags
            TagManagementView()
                .tabItem { Label("Tags", systemImage: "tag.fill") }
                .tag(2)
        }
        // Restore any in-progress task if app is relaunched mid-task
        .onAppear {
            timerViewModel.restoreIfNeeded(from: allTasks)
        }
        // Listen for notification-triggered check-in
        .onReceive(NotificationCenter.default.publisher(for: .openCheckIn)) { notification in
            guard let taskIDString = notification.userInfo?["taskID"] as? String,
                  let taskID = UUID(uuidString: taskIDString),
                  let task = allTasks.first(where: { $0.id == taskID }),
                  task.isRunning else { return }
            selectedTab = 0
            checkInTask = task
        }
        .sheet(item: $checkInTask) { task in
            CheckInView(task: task, timerViewModel: timerViewModel)
        }
    }
}
