import SwiftUI

@main
struct KcalzApp: App {
    @State private var appState = AppState.loading

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
                            appState = .failed(error)
                        }
                    }
            case .ready(let offStore, let userStore):
                DashboardView(offStore: offStore, userStore: userStore)
            case .failed(let error):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.kcCardinal)
                    Text("Impossible de charger la base")
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcEel)
                    Text(error.localizedDescription)
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcWolf)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.kcPolar)
                .ignoresSafeArea()
            }
        }
    }
}

private enum AppState {
    case loading
    case ready(OFFStore, UserStore)
    case failed(Error)
}
