import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: Session

    var body: some View {
        Group {
            switch session.stage {
            case .loading:
                VStack(spacing: 16) {
                    RecordMark(size: 64)
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            case .server:
                ServerSetupView()
            case .login:
                LoginView()
            case .ready:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.stage)
        .task { if session.stage == .loading { await session.restore() } }
    }
}
