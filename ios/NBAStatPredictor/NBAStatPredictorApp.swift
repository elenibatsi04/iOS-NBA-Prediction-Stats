import SwiftUI

@main
struct NBAStatPredictorApp: App {
    @State private var store = PredictionStore()

    var body: some Scene {
        WindowGroup {
            PlayerListView()
                .environment(store)
                .task { await store.refresh() }
        }
    }
}
