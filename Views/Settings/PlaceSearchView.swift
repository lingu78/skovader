import SwiftUI

/// Sök och välj en ort (F9) när platstillstånd saknas eller inte önskas.
struct PlaceSearchView: View {
    var onSelect: (Place) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Place] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchFailed = false

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if searchFailed {
                    Text("Sökningen fungerade inte. Kontrollera att telefonen är ansluten till internet.")
                        .foregroundStyle(.secondary)
                } else if hasSearched && results.isEmpty {
                    Text("Hittade ingen ort med det namnet.")
                        .foregroundStyle(.secondary)
                }

                ForEach(results) { place in
                    Button {
                        onSelect(place)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .foregroundStyle(.primary)
                            if let detail = place.detail {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Sök ort, t.ex. Bergen")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .navigationTitle("Välj ort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
        }
    }

    private func search() async {
        isSearching = true
        searchFailed = false
        defer {
            isSearching = false
            hasSearched = true
        }
        do {
            results = try await PlaceSearch.search(query)
        } catch {
            results = []
            searchFailed = true
        }
    }
}

#Preview {
    PlaceSearchView { _ in }
}
