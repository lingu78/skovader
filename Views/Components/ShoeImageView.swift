import SwiftUI

/// Skons bild från disk, eller en symbol om bild saknas. Läses in utanför
/// huvudtråden så att rutnätet inte hackar.
struct ShoeImageView: View {
    let fileName: String?

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "shoe.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: fileName) {
            image = await ImageStore.shared.loadImage(named: fileName)
        }
        .accessibilityHidden(true)
    }
}
