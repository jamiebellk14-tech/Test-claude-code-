import SwiftUI
import SwiftData

struct WellbeingView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = WellbeingViewModel()
    @State private var selectedPage: Int = 0
    @State private var showGoalSheet = false
    @State private var summaryService = SummaryService()

    var body: some View {
        VStack(spacing: 0) {
            BrandNavBar.custom(
                pageToggle,
                trailing: AnyView(
                    TactileNavButton(icon: "slider.horizontal.3") { showGoalSheet = true }
                )
            )

            TabView(selection: $selectedPage) {
                WellbeingTodayPage(vm: vm, summaryService: summaryService)
                    .tag(0)
                WellbeingTrendsPage(vm: vm)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
        .sheet(isPresented: $showGoalSheet) {
            WellbeingGoalSheet(vm: vm)
        }
        .onAppear {
            vm.refreshAuthorizationStatus()
            vm.load(context: context)
            vm.syncFromSharedContainer(context: context)
        }
    }

    private var pageToggle: some View {
        HStack(spacing: 0) {
            pageButton("Today", index: 0)
            pageButton("Trends", index: 1)
        }
        .padding(3)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }

    private func pageButton(_ label: String, index: Int) -> some View {
        Text(label)
            .font(.system(size: 13, weight: selectedPage == index ? .semibold : .regular))
            .foregroundStyle(selectedPage == index ? .white : Color(.secondaryLabel))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                if selectedPage == index {
                    Capsule().fill(Color(hex: "#00bf63"))
                }
            }
            .contentShape(Capsule())
            .onTapGesture { withAnimation(.spring(response: 0.3)) { selectedPage = index } }
    }
}
