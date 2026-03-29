import UIKit
import Observation

// MARK: - Tip Model

struct OptimizationTip: Identifiable {
    let id       = UUID()
    let category: Category
    let severity: Severity
    let icon:     String
    let title:    String
    let body:     String
    let actionLabel: String?
    let action:   TipAction?

    enum Category: String { case battery, storage, performance, display }

    enum Severity {
        case good, info, warning, critical
        var color: String {   // named color tokens
            switch self {
            case .good:     return "claroSuccess"
            case .info:     return "claroCyan"
            case .warning:  return "claroWarning"
            case .critical: return "claroDanger"
            }
        }
        var label: String {
            switch self {
            case .good:     return "Good"
            case .info:     return "Tip"
            case .warning:  return "Warning"
            case .critical: return "Critical"
            }
        }
    }

    enum TipAction {
        case openSettings
        case openBatterySettings
        case custom(() -> Void)
    }
}

// MARK: - Device Snapshot

struct DeviceSnapshot {
    let batteryLevel:     Float    // 0…1, -1 = unavailable (simulator)
    let batteryState:     UIDevice.BatteryState
    let isLowPowerMode:   Bool
    let thermalState:     ProcessInfo.ThermalState
    let brightness:       CGFloat  // 0…1
    let totalStorageGB:   Double
    let freeStorageGB:    Double

    var freeStoragePercent: Double {
        guard totalStorageGB > 0 else { return 1 }
        return freeStorageGB / totalStorageGB
    }

    var batteryPercent: Int { Int(batteryLevel * 100) }

    var batteryAvailable: Bool { batteryLevel >= 0 }
}

// MARK: - Service

@Observable
@MainActor
final class OptimizerService {

    private(set) var snapshot:  DeviceSnapshot?
    private(set) var tips:      [OptimizationTip] = []
    private(set) var score:     Int = 0
    private(set) var isLoading  = false

    var scoreLabel: String {
        switch score {
        case 85...100: return NSLocalizedString("Excellent",       comment: "")
        case 65..<85:  return NSLocalizedString("Good",            comment: "")
        case 45..<65:  return NSLocalizedString("Fair",            comment: "")
        default:       return NSLocalizedString("Needs Attention", comment: "")
        }
    }

    // MARK: - Scan

    func scan() {
        isLoading = true
        UIDevice.current.isBatteryMonitoringEnabled = true

        let snap = DeviceSnapshot(
            batteryLevel:   UIDevice.current.batteryLevel,
            batteryState:   UIDevice.current.batteryState,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState:   ProcessInfo.processInfo.thermalState,
            brightness:     UIScreen.main.brightness,
            totalStorageGB: diskSpace(free: false),
            freeStorageGB:  diskSpace(free: true)
        )

        snapshot = snap
        tips     = buildTips(from: snap)
        score    = computeScore(from: snap, tips: tips)
        isLoading = false
    }

    // MARK: - Score

    private func computeScore(from s: DeviceSnapshot, tips: [OptimizationTip]) -> Int {
        var pts = 100
        for tip in tips {
            switch tip.severity {
            case .critical: pts -= 22
            case .warning:  pts -= 12
            case .info:     pts -= 3
            case .good:     break
            }
        }
        return max(0, min(100, pts))
    }

    // MARK: - Tips

    private func buildTips(from s: DeviceSnapshot) -> [OptimizationTip] {
        var tips: [OptimizationTip] = []

        // ── Battery ──────────────────────────────────────────────────────
        if s.batteryAvailable {
            switch s.batteryLevel {
            case ..<0.2:
                tips.append(.init(
                    category: .battery, severity: .critical,
                    icon: "battery.0percent",
                    title: NSLocalizedString("Battery critically low", comment: ""),
                    body: String(format: NSLocalizedString("opt.battery.critical.body", comment: ""), s.batteryPercent),
                    actionLabel: nil, action: nil
                ))
            case 0.2..<0.4 where s.batteryState == .unplugged:
                tips.append(.init(
                    category: .battery, severity: .warning,
                    icon: "battery.25percent",
                    title: NSLocalizedString("Battery below 40%", comment: ""),
                    body: NSLocalizedString("opt.battery.warning.body", comment: ""),
                    actionLabel: NSLocalizedString("Open Settings", comment: ""),
                    action: .openBatterySettings
                ))
            default: break
            }

            if !s.isLowPowerMode && s.batteryState == .unplugged && s.batteryLevel < 0.5 {
                tips.append(.init(
                    category: .battery, severity: .warning,
                    icon: "bolt.slash.fill",
                    title: NSLocalizedString("Low Power Mode is off", comment: ""),
                    body: NSLocalizedString("opt.battery.lowpower.off.body", comment: ""),
                    actionLabel: NSLocalizedString("Open Settings", comment: ""),
                    action: .openBatterySettings
                ))
            }

            if s.isLowPowerMode {
                tips.append(.init(
                    category: .battery, severity: .good,
                    icon: "bolt.fill",
                    title: NSLocalizedString("Low Power Mode is on", comment: ""),
                    body: NSLocalizedString("opt.battery.lowpower.on.body", comment: ""),
                    actionLabel: nil, action: nil
                ))
            }

            if s.batteryState == .charging || s.batteryState == .full {
                tips.append(.init(
                    category: .battery, severity: .good,
                    icon: "battery.100percent.bolt",
                    title: NSLocalizedString("Charging", comment: ""),
                    body: s.batteryLevel >= 0.8
                        ? String(format: NSLocalizedString("opt.battery.charging.high.body", comment: ""), s.batteryPercent)
                        : String(format: NSLocalizedString("opt.battery.charging.body", comment: ""), s.batteryPercent),
                    actionLabel: nil, action: nil
                ))
            }
        }

        // ── Thermal ───────────────────────────────────────────────────────
        switch s.thermalState {
        case .serious:
            tips.append(.init(
                category: .performance, severity: .warning,
                icon: "thermometer.medium",
                title: NSLocalizedString("Device is warm", comment: ""),
                body: NSLocalizedString("opt.thermal.serious.body", comment: ""),
                actionLabel: nil, action: nil
            ))
        case .critical:
            tips.append(.init(
                category: .performance, severity: .critical,
                icon: "thermometer.high",
                title: NSLocalizedString("Device overheating", comment: ""),
                body: NSLocalizedString("opt.thermal.critical.body", comment: ""),
                actionLabel: nil, action: nil
            ))
        case .fair:
            tips.append(.init(
                category: .performance, severity: .info,
                icon: "thermometer.low",
                title: NSLocalizedString("Device slightly warm", comment: ""),
                body: NSLocalizedString("opt.thermal.fair.body", comment: ""),
                actionLabel: nil, action: nil
            ))
        default: // .nominal
            tips.append(.init(
                category: .performance, severity: .good,
                icon: "thermometer.variable.and.figure",
                title: NSLocalizedString("Temperature normal", comment: ""),
                body: NSLocalizedString("opt.thermal.nominal.body", comment: ""),
                actionLabel: nil, action: nil
            ))
        }

        // ── Storage ───────────────────────────────────────────────────────
        switch s.freeStoragePercent {
        case ..<0.05:
            tips.append(.init(
                category: .storage, severity: .critical,
                icon: "internaldrive.fill",
                title: NSLocalizedString("Storage almost full", comment: ""),
                body: String(format: NSLocalizedString("opt.storage.critical.body", comment: ""), s.freeStorageGB, s.totalStorageGB),
                actionLabel: NSLocalizedString("Clean Now", comment: ""),
                action: .custom({})
            ))
        case 0.05..<0.15:
            tips.append(.init(
                category: .storage, severity: .warning,
                icon: "internaldrive.fill",
                title: NSLocalizedString("Storage running low", comment: ""),
                body: String(format: NSLocalizedString("opt.storage.warning.body", comment: ""), s.freeStorageGB, s.totalStorageGB),
                actionLabel: NSLocalizedString("Clean Now", comment: ""),
                action: .custom({})
            ))
        default:
            tips.append(.init(
                category: .storage, severity: .good,
                icon: "internaldrive.fill",
                title: NSLocalizedString("Storage looks good", comment: ""),
                body: String(format: NSLocalizedString("opt.storage.good.body", comment: ""), s.freeStorageGB, s.totalStorageGB, s.freeStoragePercent * 100),
                actionLabel: nil, action: nil
            ))
        }

        // ── Display ───────────────────────────────────────────────────────
        if s.brightness > 0.8 {
            tips.append(.init(
                category: .display, severity: .info,
                icon: "sun.max.fill",
                title: NSLocalizedString("Screen brightness is high", comment: ""),
                body: String(format: NSLocalizedString("opt.brightness.high.body", comment: ""), Int(s.brightness * 100)),
                actionLabel: nil, action: nil
            ))
        } else {
            tips.append(.init(
                category: .display, severity: .good,
                icon: "sun.min.fill",
                title: NSLocalizedString("Brightness is efficient", comment: ""),
                body: String(format: NSLocalizedString("opt.brightness.good.body", comment: ""), Int(s.brightness * 100)),
                actionLabel: nil, action: nil
            ))
        }

        // ── Background App Refresh tip ─────────────────────────────────
        tips.append(.init(
            category: .performance, severity: .info,
            icon: "arrow.clockwise.circle.fill",
            title: NSLocalizedString("Review Background App Refresh", comment: ""),
            body: NSLocalizedString("opt.background.refresh.body", comment: ""),
            actionLabel: NSLocalizedString("Open Settings", comment: ""),
            action: .openSettings
        ))

        return tips
    }

    // MARK: - Disk space

    private func diskSpace(free: Bool) -> Double {
        let key: FileAttributeKey = free ? .systemFreeSize : .systemSize
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let bytes = attrs?[key] as? Int64 ?? 0
        return Double(bytes) / 1_073_741_824
    }
}
