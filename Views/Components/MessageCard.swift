import SwiftUI

/// Ett vänligt kort med rubrik, förklaring och knappar.
struct MessageCard<Actions: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { actions }
                VStack(alignment: .leading, spacing: 12) { actions }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
