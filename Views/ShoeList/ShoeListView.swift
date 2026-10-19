import SwiftData
import SwiftUI

/// Mina skor (F5): rutnät med bilder. Tryck öppnar redigering, långtryck ger
/// en meny där skon kan tas bort efter bekräftelse.
struct ShoeListView: View {
    /// Sätts av Idag eller introduktionen för att öppna "Ny sko" direkt.
    @Binding var addShoeRequested: Bool

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Shoe.createdAt) private var shoes: [Shoe]

    @State private var editorTarget: EditorTarget?
    @State private var pendingDeletion: PendingDeletion?
    /// Sko som ska tas bort när redigeringsarket har stängts.
    @State private var deleteAfterEditor: Shoe?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if shoes.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .navigationTitle("Mina skor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Lägg till sko", systemImage: "plus") {
                        editorTarget = EditorTarget(shoe: nil)
                    }
                }
            }
            .onAppear(perform: openRequestedEditor)
            .onChange(of: addShoeRequested) { _, _ in openRequestedEditor() }
            .sheet(item: $editorTarget, onDismiss: deleteShoeFromEditor) { target in
                ShoeEditorView(shoe: target.shoe) { shoe in
                    deleteAfterEditor = shoe
                }
            }
            .confirmationDialog(
                "Ta bort skon?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { pending in
                Button("Ta bort", role: .destructive) {
                    ShoeLibrary.delete(pending.shoe, from: modelContext)
                }
                Button("Avbryt", role: .cancel) {}
            } message: { pending in
                Text("\(pending.title) tas bort tillsammans med bilden och historiken.")
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(shoes) { shoe in
                    Button {
                        editorTarget = EditorTarget(shoe: shoe)
                    } label: {
                        ShoeCard(shoe: shoe)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Redigera", systemImage: "pencil") {
                            editorTarget = EditorTarget(shoe: shoe)
                        }
                        Button("Ta bort", systemImage: "trash", role: .destructive) {
                            pendingDeletion = PendingDeletion(shoe: shoe, title: shoe.title)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Inga skor än", systemImage: "shoe.2")
        } description: {
            Text("Fotografera dina skor så kan Skoväder föreslå vilka som passar dagens väder.")
        } actions: {
            Button("Lägg till sko") {
                editorTarget = EditorTarget(shoe: nil)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func openRequestedEditor() {
        guard addShoeRequested else { return }
        addShoeRequested = false
        editorTarget = EditorTarget(shoe: nil)
    }

    private func deleteShoeFromEditor() {
        guard let shoe = deleteAfterEditor else { return }
        deleteAfterEditor = nil
        ShoeLibrary.delete(shoe, from: modelContext)
    }
}

private struct EditorTarget: Identifiable {
    let id = UUID()
    let shoe: Shoe?
}

/// Namnet sparas när menyn öppnas, så att dialogen inte läser från en
/// sko som redan tagits bort.
private struct PendingDeletion {
    let shoe: Shoe
    let title: String
}

#Preview {
    ShoeListView(addShoeRequested: .constant(false))
        .modelContainer(for: [Shoe.self, WearLog.self], inMemory: true)
}
