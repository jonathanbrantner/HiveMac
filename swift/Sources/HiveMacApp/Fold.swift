import SwiftUI

/// A section that opens and closes. The whole row is the button, so it is easy to hit (the built-in arrow is tiny).
struct Fold<Content: View>: View {
    var title: String
    var tint: Color = Theme.wax
    @Binding var isOpen: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.snappy(duration: 0.15)) { isOpen.toggle() } } label: {
                HStack(spacing: Theme.s2) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right").font(.system(size: 10, weight: .bold)).frame(width: 14)
                    Text(title).font(Theme.bodyStrong)
                    Spacer()
                }
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen { content.padding(.top, Theme.s1) }
        }
    }
}
