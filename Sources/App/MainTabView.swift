import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: Session
    @State private var tab = Tab.overview

    enum Tab: Hashable { case overview, history, wrapped, friends, settings }

    var body: some View {
        VStack(spacing: 0) {
            if let viewing = session.viewing {
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                    Text(String(format: String(localized: "Viewing %@"), viewing.name))
                    Spacer()
                    Button(String(localized: "Back to mine")) { session.viewing = nil }
                        .font(.footnote.weight(.semibold))
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
            }

            TabView(selection: $tab) {
                OverviewView()
                    .tabItem { Label("Overview", systemImage: "chart.bar.fill") }
                    .tag(Tab.overview)
                HistoryView()
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                    .tag(Tab.history)
                WrappedView()
                    .tabItem { Label("Wrapped", systemImage: "sparkles") }
                    .tag(Tab.wrapped)
                if !session.isDemo {
                    FriendsView()
                        .tabItem { Label("Friends", systemImage: "person.2.fill") }
                        .tag(Tab.friends)
                }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(Tab.settings)
            }
        }
        .onChange(of: session.viewing) { viewing in
            // Friends is about my own connections, so looking at someone
            // else's numbers moves the app to the overview.
            if viewing != nil { tab = .overview }
        }
    }
}
