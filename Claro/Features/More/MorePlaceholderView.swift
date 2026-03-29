import SwiftUI

// "..." tab — content TBD.
// Intentionally empty; will be filled in the next iteration.
struct MorePlaceholderView: View {
    var body: some View {
        ZStack {
            Color.claroBg.ignoresSafeArea()

            VStack(spacing: ClaroSpacing.md) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.claroTextMuted)

                Text("Coming Soon")
                    .font(.claroHeadline())
                    .foregroundStyle(Color.claroTextSecondary)
            }
        }
        .navigationTitle("")
    }
}

#Preview {
    MorePlaceholderView()
}
