import SwiftUI

struct ProBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: 9, weight: .bold))
            Text("PRO")
                .font(.claroLabel())
                .kerning(0.5)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            LinearGradient(
                colors: [Color(hex: "#F59E0B"), Color(hex: "#D97706")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
    }
}

#Preview {
    ProBadge()
        .padding()
        .background(Color.claroBg)
}
