import SwiftUI

/// En ruta i Mina skor: stor bild, namn och typ.
struct ShoeCard: View {
    let shoe: Shoe

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ShoeImageView(fileName: shoe.imageFileName)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .padding(10)
                .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if !shoe.isActive {
                        Text("Inaktiv")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())
                            .padding(8)
                    }
                }

            Text(shoe.title)
                .font(.headline)
                .lineLimit(2)
            Text(shoe.type.localizedName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .opacity(shoe.isActive ? 1 : 0.6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
