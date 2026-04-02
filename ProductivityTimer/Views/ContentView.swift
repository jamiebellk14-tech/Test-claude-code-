import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var allTasks: [TaskEntry]
    @Environment(\.modelContext) private var context

    @State private var timerViewModel = TimerViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // All tab views rendered simultaneously — opacity-switched to preserve state
            timerContent
                .allowsHitTesting(selectedTab == 0)
                .opacity(selectedTab == 0 ? 1 : 0)

            ReportsView()
                .allowsHitTesting(selectedTab == 1)
                .opacity(selectedTab == 1 ? 1 : 0)

            ScheduleView(timerViewModel: timerViewModel, selectedTab: $selectedTab)
                .allowsHitTesting(selectedTab == 2)
                .opacity(selectedTab == 2 ? 1 : 0)

            TagManagementView()
                .allowsHitTesting(selectedTab == 3)
                .opacity(selectedTab == 3 ? 1 : 0)

            ProductivityAIView()
                .allowsHitTesting(selectedTab == 4)
                .opacity(selectedTab == 4 ? 1 : 0)

            // Floating tactile tab bar
            TactileTabBar(selectedTab: $selectedTab)
        }
        .safeAreaInset(edge: .bottom) {
            // Reserve space so content isn't hidden behind the floating bar
            Color.clear.frame(height: 90)
        }
        .tint(Color(hex: "#00bf63"))
        .onAppear {
            timerViewModel.restoreIfNeeded(from: allTasks)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCheckIn)) { _ in
            selectedTab = 0
        }
    }

    private var timerContent: some View {
        Group {
            if timerViewModel.isRunning {
                ActiveTimerView(timerViewModel: timerViewModel)
            } else {
                HomeView(timerViewModel: timerViewModel)
            }
        }
    }
}
