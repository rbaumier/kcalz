import SwiftUI

/// App entry point — bootstraps stores and routes to the dashboard or an error screen.
@main
struct KcalzApp: App {
    private enum Layout {
        static let errorIconSize: CGFloat = 40
        static let errorHorizontalPadding: CGFloat = 32
    }

    @State private var appState = AppState.loading

    /// Main scene: loading splash, dashboard, or error depending on `appState`.
    var body: some Scene {
        WindowGroup {
            switch appState {
            case .loading:
                Color.kcPolar
                    .ignoresSafeArea()
                    .task {
                        do {
                            let offStore = try OFFStore()
                            let userStore = try UserStore()
                            appState = .ready(offStore, userStore)
                        } catch {
                            appState = .failed(error.localizedDescription)
                        }
                    }
            case .ready(let offStore, let userStore):
                DashboardView(offStore: offStore, userStore: userStore)
            case .failed(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: Layout.errorIconSize))
                        .foregroundStyle(Color.kcCardinal)
                    Text("Impossible de charger la base")
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcEel)
                    Text(message)
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcWolf)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Layout.errorHorizontalPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.kcPolar)
                .ignoresSafeArea()
            }
        }
    }
}

/// Tri-state for app initialization: loading, ready with stores, or failed with message.
private enum AppState {
    case loading
    case ready(OFFStore, UserStore)
    case failed(String)
}
