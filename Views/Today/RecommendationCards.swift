import SwiftUI
import SkovaderEngine

/// Förslaget: eventuellt "passar inte riktigt", huvudförslaget och
/// upp till två alternativ (F7).
struct SuggestionView: View {
    let suggestion: Suggestion
    let shoes: [Shoe]
    let chosenID: UUID?
    let onChoose: (Shoe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let message = suggestion.poorFitMessage {
                Label(message, systemImage: "hand.wave.fill")
                    .font(.callout)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if let shoe = shoe(for: suggestion.primary) {
                RecommendationCard(
                    shoe: shoe,
                    explanation: suggestion.primary.explanation,
                    isChosen: chosenID == shoe.id
                ) { onChoose(shoe) }
            }

            if !suggestion.alternatives.isEmpty {
                Text("Alternativ")
                    .font(.title3.bold())
                    .padding(.top, 8)
                ForEach(suggestion.alternatives) { alternative in
                    if let shoe = shoe(for: alternative) {
                        AlternativeRow(
                            shoe: shoe,
                            explanation: alternative.explanation,
                            isChosen: chosenID == shoe.id
                        ) { onChoose(shoe) }
                    }
                }
            }

            if let chosen = chosenElsewhere {
                Label("Idag har du valt \(chosen.title).", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func shoe(for scored: ScoredShoe) -> Shoe? {
        shoes.first { $0.id == scored.id }
    }

    /// Dagens val om det inte är något av de föreslagna paren.
    private var chosenElsewhere: Shoe? {
        guard let chosenID else { return nil }
        let shown = [suggestion.primary.id] + suggestion.alternatives.map(\.id)
        guard !shown.contains(chosenID) else { return nil }
        return shoes.first { $0.id == chosenID }
    }
}

/// Det stora kortet med dagens rekommenderade skor.
struct RecommendationCard: View {
    let shoe: Shoe
    let explanation: String
    let isChosen: Bool
    let onChoose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShoeImageView(fileName: shoe.imageFileName)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .padding(16)
                .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            Text(shoe.title)
                .font(.title.bold())
            Text(explanation)
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)
            ChooseButton(isChosen: isChosen, prominent: true, action: onChoose)
        }
    }
}

/// Ett alternativ under huvudförslaget.
struct AlternativeRow: View {
    let shoe: Shoe
    let explanation: String
    let isChosen: Bool
    let onChoose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ShoeImageView(fileName: shoe.imageFileName)
                .frame(width: 88, height: 88)
                .padding(6)
                .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(shoe.title)
                    .font(.headline)
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ChooseButton(isChosen: isChosen, prominent: false, action: onChoose)
            }
        }
    }
}

/// "Jag tar dessa" (F8), eller en bock om skorna redan valts idag.
struct ChooseButton: View {
    let isChosen: Bool
    let prominent: Bool
    let action: () -> Void

    var body: some View {
        if isChosen {
            Label("Valda idag", systemImage: "checkmark.circle.fill")
                .font(prominent ? .headline : .subheadline)
                .foregroundStyle(.green)
                .padding(.vertical, prominent ? 12 : 4)
        } else if prominent {
            Button(action: action) {
                Text("Jag tar dessa")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button("Ta dessa i stället", action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}
