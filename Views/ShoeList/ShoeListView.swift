import SwiftUI
import SwiftData

/// Mina skor. Rutnät, kamera och redigering kommer i etapp 2.
struct ShoeListView: View {
    @Query(sort: \Shoe.createdAt) private var shoes: [Shoe]

    var body: some View {
        NavigationStack {
            Group {
                if shoes.isEmpty {
                    ContentUnavailableView(
                        "Inga skor än",
                        systemImage: "shoe.2",
                        description: Text("Här samlas dina skor.")
                    )
                } else {
                    List(shoes) { shoe in
                        VStack(alignment: .leading) {
                            Text(shoe.name)
                            Text(shoe.type.localizedName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Mina skor")
        }
    }
}

#Preview {
    ShoeListView()
        .modelContainer(for: [Shoe.self, WearLog.self], inMemory: true)
}
