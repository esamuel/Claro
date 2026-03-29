import SwiftUI

struct OptimizerView: View {
    @State private var service = OptimizerService()

    var body: some View {
        ZStack {
            Color.claroBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: ClaroSpacing.lg) {

                    scoreCard
                        .padding(.horizontal)

                    if let snap = service.snapshot {
                        quickStats(snap)
                            .padding(.horizontal)
                    }

                    if !service.tips.isEmpty {
                        VStack(alignment: .leading, spacing: ClaroSpacing.sm) {
                            ClaroSectionLabel(title: "Recommendations")
                                .padding(.horizontal)

                            ForEach(service.tips) { tip in
                                TipCard(tip: tip)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // Rescan button
                    Button { service.scan() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Rescan")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Color.claroTextMuted)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Spacer(minLength: ClaroSpacing.xxl)
                }
                .padding(.top, ClaroSpacing.md)
            }
        }
        .navigationTitle("Optimizer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { service.scan() }
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0A1628"), Color(hex: "#1A0A3E")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Glow behind the ring
            Circle()
                .fill(scoreColor.opacity(0.2))
                .frame(width: 160, height: 160)
                .blur(radius: 55)

            VStack(spacing: ClaroSpacing.md) {
                // Score ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 10)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: CGFloat(service.score) / 100)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: service.score)

                    VStack(spacing: 2) {
                        Text("\(service.score)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.easeInOut, value: service.score)
                        Text(service.scoreLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(scoreColor)
                            .textCase(.uppercase)
                            .kerning(1)
                    }
                }

                Text("Device Health Score")
                    .font(.claroCaption())
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(ClaroSpacing.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.lg)
                .strokeBorder(scoreColor.opacity(0.3), lineWidth: 1)
        )
        .frame(minHeight: 220)
        .claroCardShadow()
    }

    private var scoreColor: Color {
        switch service.score {
        case 85...100: return .claroSuccess
        case 65..<85:  return .claroGold
        case 45..<65:  return .claroWarning
        default:       return .claroDanger
        }
    }

    // MARK: - Quick Stats

    private func quickStats(_ snap: DeviceSnapshot) -> some View {
        HStack(spacing: 10) {
            if snap.batteryAvailable {
                StatChip(
                    icon: batteryIcon(snap),
                    label: "Battery",
                    value: "\(snap.batteryPercent)%",
                    color: snap.batteryLevel < 0.2 ? .claroDanger : snap.batteryLevel < 0.5 ? .claroWarning : .claroSuccess
                )
            }

            StatChip(
                icon: "internaldrive.fill",
                label: "Free",
                value: String(format: "%.1f GB", snap.freeStorageGB),
                color: snap.freeStoragePercent < 0.1 ? .claroDanger : snap.freeStoragePercent < 0.2 ? .claroWarning : .claroSuccess
            )

            StatChip(
                icon: "thermometer.medium",
                label: "Temp",
                value: thermalLabel(snap.thermalState),
                color: thermalColor(snap.thermalState)
            )

            StatChip(
                icon: "sun.max.fill",
                label: "Brightness",
                value: "\(Int(snap.brightness * 100))%",
                color: snap.brightness > 0.8 ? .claroWarning : .claroSuccess
            )
        }
    }

    private func batteryIcon(_ snap: DeviceSnapshot) -> String {
        if snap.batteryState == .charging || snap.batteryState == .full { return "battery.100percent.bolt" }
        switch snap.batteryLevel {
        case ..<0.25: return "battery.0percent"
        case 0.25..<0.5: return "battery.25percent"
        case 0.5..<0.75: return "battery.50percent"
        default: return "battery.100percent"
        }
    }

    private func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:    return NSLocalizedString("Normal",   comment: "")
        case .fair:       return NSLocalizedString("Warm",     comment: "")
        case .serious:    return NSLocalizedString("Hot",      comment: "")
        case .critical:   return NSLocalizedString("Critical", comment: "")
        @unknown default: return "—"
        }
    }

    private func thermalColor(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal:  return .claroSuccess
        case .fair:     return .claroGold
        case .serious:  return .claroWarning
        case .critical: return .claroDanger
        @unknown default: return .claroTextMuted
        }
    }
}

// MARK: - Stat Chip

private struct StatChip: View {
    let icon:  String
    let label: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.claroTextPrimary)
            Text(label)
                .font(.claroLabel())
                .foregroundStyle(Color.claroTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.md)
                .strokeBorder(color.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Tip Card

private struct TipCard: View {
    let tip: OptimizationTip

    private var color: Color {
        switch tip.severity {
        case .good:     return .claroSuccess
        case .info:     return .claroCyan
        case .warning:  return .claroWarning
        case .critical: return .claroDanger
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Severity stripe + icon
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: tip.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(color)
                }

                // Severity badge
                Text(LocalizedStringKey(tip.severity.label))
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(color)
                    .kerning(0.5)
                    .textCase(.uppercase)
                    .padding(.top, 4)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(tip.title)
                    .font(.claroHeadline())
                    .foregroundStyle(Color.claroTextPrimary)

                Text(tip.body)
                    .font(.claroCaption())
                    .foregroundStyle(Color.claroTextSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let label = tip.actionLabel, let action = tip.action {
                    Button {
                        switch action {
                        case .openSettings:
                            // Opens Claro's page in Settings — shows Background App Refresh toggle
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        case .openBatterySettings:
                            // Opens Claro's page in Settings — shows battery-related permissions
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        case .custom(let fn): fn()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(label)
                                .font(.system(size: 12, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.md)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview { OptimizerView() }
