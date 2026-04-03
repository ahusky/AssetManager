import SwiftUI

@main
struct AssetManagerApp: App {
    @StateObject private var store = AssetStore()

    var body: some Scene {
        WindowGroup {
            AssetListView()
                .environmentObject(store)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1300, height: 700)
    }
}
