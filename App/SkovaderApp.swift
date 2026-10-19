import SwiftUI
import SwiftData

@main
struct SkovaderApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Shoe.self, WearLog.self])
    }
}
