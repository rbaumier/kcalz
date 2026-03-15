import SwiftUI

/// Floating action bar shown during multi-select mode with copy, delete, and cancel actions.
struct SelectionActionBar: View {
    let count: Int
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button { onCancel() } label: {
                Text("Annuler")
                    .font(.kcBody)
                    .foregroundStyle(Color.kcSnow)
            }

            Spacer()

            Text("\(count) sél.")
                .font(.kcBody)
                .foregroundStyle(Color.kcSnow.opacity(0.7))
                .lineLimit(1)

            Spacer()

            Button { onCopy() } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.kcSnow)
                    .frame(width: Theme.buttonSize, height: Theme.buttonSize)
            }
            .accessibilityLabel("Copier")
            .disabled(count == 0)
            .opacity(count == 0 ? 0.4 : 1)

            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.kcCardinal)
                    .frame(width: Theme.buttonSize, height: Theme.buttonSize)
            }
            .accessibilityLabel("Supprimer")
            .disabled(count == 0)
            .opacity(count == 0 ? 0.4 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.kcEel)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusL, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}
