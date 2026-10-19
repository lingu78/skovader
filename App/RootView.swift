import SwiftUI
import SwiftData

/// De två flikarna: Idag (startsida) och Mina skor. Introduktionen visas
/// första gången appen startas.
struct RootView: View {
    private enum Tab: Hashable {
        case today
        case shoes
    }

    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @State private var tab = Tab.today
    @State private var addShoeRequested = false
    @State private var addShoeAfterOnboarding = false
    @State private var weather = WeatherStore.live()

    var body: some View {
        TabView(selection: $tab) {
            TodayView(weather: weather, onAddShoe: requestAddShoe)
                .tabItem { Label("Idag", systemImage: "sun.max") }
                .tag(Tab.today)
            ShoeListView(addShoeRequested: $addShoeRequested)
                .tabItem { Label("Mina skor", systemImage: "shoe.2") }
                .tag(Tab.shoes)
        }
        .fullScreenCover(isPresented: showOnboarding, onDismiss: {
            // Redigeraren öppnas först när introduktionen har stängts.
            if addShoeAfterOnboarding {
                addShoeAfterOnboarding = false
                requestAddShoe()
            }
        }) {
            OnboardingView(weather: weather) { addShoe in
                addShoeAfterOnboarding = addShoe
                hasOnboarded = true
            }
        }
    }

    private var showOnboarding: Binding<Bool> {
        Binding {
            !hasOnboarded
        } set: { isShown in
            if !isShown { hasOnboarded = true }
        }
    }

    private func requestAddShoe() {
        tab = .shoes
        addShoeRequested = true
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Shoe.self, WearLog.self], inMemory: true)
}
