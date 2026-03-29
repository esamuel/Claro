import SwiftUI

// MARK: - Permission Request (not determined)

struct PermissionRequestView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let buttonTitle: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: ClaroSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(iconColor)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.claroTitle())
                    .foregroundStyle(Color.claroTextPrimary)
                Text(description)
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [iconColor, iconColor.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                    .claroGlowShadow(color: iconColor)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Permission Denied (go to Settings)

struct PermissionDeniedView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: ClaroSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.claroDanger.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "xmark.shield.fill")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(Color.claroDanger)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.claroTitle())
                    .foregroundStyle(Color.claroTextPrimary)
                Text(description)
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 15)
                .background(Color.claroDanger)
                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                .claroGlowShadow(color: .claroDanger)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
