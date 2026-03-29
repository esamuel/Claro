import SwiftUI
import Photos

/// Full-screen cover that runs the AI scan then shows results in-place.
struct SmartCleanView: View {
    @Environment(PermissionsService.self)    private var permissions
    @Environment(StoreKitService.self)       private var store
    @Environment(DuplicatePhotoService.self) private var photoService
    @Environment(ICloudService.self)         private var iCloudService
    @Environment(ContactService.self)        private var contactService
    @Environment(\.dismiss)                 private var dismiss

    var onReviewPhotos:   (() -> Void)? = nil
    var onReviewICloud:   (() -> Void)? = nil
    var onReviewContacts: (() -> Void)? = nil

    @State private var scanner = ScanService()

    var body: some View {
        ZStack {
            Color.claroBg.ignoresSafeArea()

            switch scanner.phase {
            case .idle:
                // Kick off scan immediately
                Color.clear.task { await startScan() }

            case .scanning(let stage, _):
                ScanningAnimationView(
                    stage:            stage,
                    stageIndex:       scanner.currentStageIndex,
                    stageProgress:    scanner.stageProgress
                )

            case .done:
                ScanResultsView(
                    results:         scanner.results,
                    onReviewPhotos:  onReviewPhotos,
                    onReviewICloud:  onReviewICloud,
                    onReviewContacts: onReviewContacts
                ) { dismiss() }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .opacity
                        )
                    )

            case .failed(let msg):
                ErrorView(message: msg) { dismiss() }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isDone)
    }

    private var isDone: Bool {
        if case .done = scanner.phase { return true }
        return false
    }

    private func startScan() async {
        await scanner.startScan(
            photoAccess:    permissions.photoStatus.isGranted,
            contactAccess:  permissions.contactStatus.isGranted,
            photoService:   photoService,
            iCloudService:  iCloudService,
            contactService: contactService
        )
    }
}

// MARK: - Scanning Animation

struct ScanningAnimationView: View {
    let stage:         ScanService.Stage
    let stageIndex:    Int
    let stageProgress: Double

    @State private var pulse      = false
    @State private var dotOffset  = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Pulsing icon ─────────────────────────────────────────────
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .strokeBorder(stage.color.opacity(0.12 - Double(i) * 0.03), lineWidth: 1.5)
                        .frame(
                            width:  CGFloat(80 + i * 40),
                            height: CGFloat(80 + i * 40)
                        )
                        .scaleEffect(pulse ? 1.06 : 0.98)
                        .animation(
                            .easeInOut(duration: 1.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.25),
                            value: pulse
                        )
                }

                Circle()
                    .fill(stage.color.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: stage.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(stage.color)
                    .symbolEffect(.pulse, value: pulse)
            }
            .padding(.bottom, 40)
            .onAppear { pulse = true }

            // ── Title ────────────────────────────────────────────────────
            VStack(spacing: 8) {
                Text(stage.rawValue)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.claroTextPrimary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: stage)

                Text("AI is analyzing your data…")
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
            }
            .padding(.bottom, 36)

            // ── Stage tracker ────────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(Array(ScanService.Stage.allCases.enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 0) {
                        // Circle
                        ZStack {
                            Circle()
                                .fill(
                                    i < stageIndex ? Color.claroSuccess :
                                    i == stageIndex ? s.color :
                                    Color.claroCard
                                )
                                .frame(width: 32, height: 32)

                            if i < stageIndex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: s.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(
                                        i == stageIndex ? .white : Color.claroTextMuted
                                    )
                            }
                        }
                        .animation(.spring(response: 0.4), value: stageIndex)

                        // Connector
                        if i < ScanService.Stage.allCases.count - 1 {
                            Rectangle()
                                .fill(i < stageIndex ? Color.claroSuccess : Color.claroCardBorder)
                                .frame(height: 2)
                                .frame(maxWidth: 40)
                                .animation(.easeInOut(duration: 0.3), value: stageIndex)
                        }
                    }
                }
            }
            .padding(.bottom, 32)

            // ── Stage progress bar ───────────────────────────────────────
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.claroCard)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [stage.color, stage.color.opacity(0.5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(8, geo.size.width * stageProgress),
                                height: 6
                            )
                            .animation(.easeInOut(duration: 0.25), value: stageProgress)
                    }
                }
                .frame(height: 6)

                Text("\(Int(stageProgress * 100))%")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.claroTextMuted)
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.claroWarning)
            Text(message)
                .font(.claroBody())
                .foregroundStyle(Color.claroTextSecondary)
                .multilineTextAlignment(.center)
            Button("Dismiss", action: onDismiss)
                .font(.claroHeadline())
                .foregroundStyle(Color.claroViolet)
        }
        .padding()
    }
}

#Preview {
    SmartCleanView()
        .environment(PermissionsService())
        .environment(StoreKitService())
}
