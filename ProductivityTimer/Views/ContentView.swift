import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var allTasks: [TaskEntry]
    @Environment(\.modelContext) private var context

    @State private var timerViewModel = TimerViewModel()
    @State private var selectedTab: Int = 0

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

            // Tab 2: Schedule
            ScheduleView(timerViewModel: timerViewModel, selectedTab: $selectedTab)
                .tabItem { Label("Schedule", systemImage: "list.bullet.clipboard") }
                .tag(2)

            // Tab 3: Tags
            TagManagementView()
                .tabItem { Label("Tags", systemImage: "tag.fill") }
                .tag(3)

            // Tab 4: Productivity AI
            ProductivityAIView()
                .tabItem { Label("AI", systemImage: "sparkles") }
                .tag(4)
        }
        // Restore any in-progress task if app is relaunched mid-task
        .onAppear {
            timerViewModel.restoreIfNeeded(from: allTasks)
        }
        // Notification tap → just jump to the Timer tab
        .onReceive(NotificationCenter.default.publisher(for: .openCheckIn)) { _ in
            selectedTab = 0
        }
    }
}
