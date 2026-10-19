import SwiftUI
import SwiftData

/// Startsidan. Väder och rekommendation kommer i etapp 3; här finns bara
/// tomt läge (F10) och en platshållare.
struct TodayView: View {
    @Query private var shoes: [Shoe]

    var body: some View {
        NavigationStack {
            Group {
                if shoes.isEmpty {
                    ContentUnavailableView(
                        "Inga skor än",
                        systemImage: "shoe.2",
                        description: Text("Lägg till dina skor under Mina skor, så får du ett förslag varje morgon.")
                    )
                } else {
                    ContentUnavailableView(
                        "Dagens förslag kommer snart",
                        systemImage: "cloud.sun",
                        description: Text("Väder och rekommendation byggs i etapp 3.")
                    )
                }
            }
            .navigationTitle("Idag")
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [Shoe.self, WearLog.self], inMemory: true)
}
