import SwiftUI

@main
struct KcalzApp: App {
    @State private var offStore: OFFStore?

    var body: some Scene {
        WindowGroup {
            if let store = offStore {
                DashboardView(offStore: store)
            } else {
                Color.kcPolar
                    .ignoresSafeArea()
                    .onAppear {
                        offStore = try? OFFStore()
                    }
            }
        }
    }
}
