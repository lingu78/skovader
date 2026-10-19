import SwiftUI
import SwiftData

/// De två flikarna: Idag (startsida) och Mina skor.
struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Idag", systemImage: "sun.max") }
            ShoeListView()
                .tabItem { Label("Mina skor", systemImage: "shoe.2") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Shoe.self, WearLog.self], inMemory: true)
}
