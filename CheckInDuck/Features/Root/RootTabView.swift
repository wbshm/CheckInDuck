import SwiftUI
import Combine

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var todayViewModel = TodayViewModel()
    @StateObject private var subscriptionAccess = SubscriptionAccessService()
    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            TodayView(
                viewModel: todayViewModel,
                subscriptionAccess: subscriptionAccess
            )
                .tabItem {
                    Label("Today", systemImage: "checklist")
                }

            HistoryView(subscriptionAccess: subscriptionAccess)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SettingsView(subscriptionAccess: subscriptionAccess)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear {
            todayViewModel.refreshForForeground()
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            todayViewModel.refreshForForeground()
        }
        .onReceive(refreshTimer) { _ in
            guard scenePhase == .active else { return }
            todayViewModel.evaluateDailyStatuses()
        }
    }
}

#Preview {
    RootTabView()
}
