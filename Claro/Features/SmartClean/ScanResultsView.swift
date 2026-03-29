import SwiftUI
import Photos

/// Shows what the AI scan found and lets the user select what to clean.
struct ScanResultsView: View {
    let results:        ScanResults
    var onReviewPhotos:   (() -> Void)? = nil
    var onReviewICloud:   (() -> Void)? = nil
    var onReviewContacts: (() -> Void)? = nil
    var onDismiss:        () -> Void

    @Environment(StoreKitService.self) private var store
    @State private var selected:    Set<CleanCategory> = [.photos, .contacts, .iCloud]
    @State private var showPaywall  = false

    enum CleanCategory: String, CaseIterable, Hashable {
        case photos, contacts, iCloud
    }

    var estimatedGB: Double {
        let photoGB = results.reclaimableGB > 0.01
            ? results.reclaimableGB
            : Double(results.duplicatePhotoCount) * 0.004
        return photoGB + results.largeMediaGB
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Header ───────────────────────────────────────────────
                headerSection
                    .padding(.top, 36)
                    .padding(.bottom, 28)

                if !results.isEmpty {
                    categoryCards
                        .padding(.horizontal, 20)

                    ctaButtons
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 48)
                } else {
                    allCleanButton
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 48)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                photoDuplicates: results.duplicatePhotoCount,
                contactDups:     results.duplicateContactCount,
                reclaimableGB:   estimatedGB
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.claroSuccess.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: results.isEmpty ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(results.isEmpty ? Color.claroSuccess : Color.claroGold)
            }

            if results.isEmpty {
                Text("All Clean! 🎉")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Color.claroTextPrimary)
                Text("Your phone is already optimized.")
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(String(format: "%.1f GB found", estimatedGB))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(Color.claroTextPrimary)
                Text("Ready to be cleaned")
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Category Cards

    private var categoryCards: some View {
        VStack(spacing: 12) {
            if results.duplicatePhotoCount > 0 {
                ScanCategoryCard(
                    icon:       "photo.stack.fill",
                    color:      .claroVioletLight,
                    title:      "Duplicate Photos",
                    count:      "\(results.duplicatePhotoCount) duplicates",
                    detail:     String(format: "≈ %.1f GB", results.reclaimableGB),
                    isSelected: selected.contains(.photos)
                ) { withAnimation(.easeInOut(duration: 0.15)) { toggle(.photos) } }
            }

            if results.duplicateContactCount > 0 {
                ScanCategoryCard(
                    icon:       "person.2.fill",
                    color:      .claroGold,
                    title:      "Duplicate Contacts",
                    count:      "\(results.duplicateContactCount) duplicates",
                    detail:     "\(results.contactGroups.count) groups",
                    isSelected: selected.contains(.contacts)
                ) { withAnimation(.easeInOut(duration: 0.15)) { toggle(.contacts) } }
            }

            if results.largeMediaCount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    ScanCategoryCard(
                        icon:       "internaldrive.fill",
                        color:      .claroCyan,
                        title:      "Large Files",
                        count:      "\(results.largeMediaCount) files",
                        detail:     String(format: "%.1f GB", results.largeMediaGB),
                        isSelected: selected.contains(.iCloud)
                    ) { withAnimation(.easeInOut(duration: 0.15)) { toggle(.iCloud) } }

                    InfoNote(text: "Biggest files by size — not duplicates. Review before deleting.")
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - CTA Buttons

    private var ctaButtons: some View {
        VStack(spacing: 14) {
            Button {
                if store.isPro {
                    // Route to the highest-priority selected category
                    if selected.contains(.photos)    { onReviewPhotos?() }
                    else if selected.contains(.contacts) { onReviewContacts?() }
                    else if selected.contains(.iCloud)   { onReviewICloud?() }
                    else { onDismiss() }
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: 8) {
                    if !store.isPro {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(store.isPro ? "Review & Clean" : "Unlock to Clean All")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [Color.claroViolet, Color(hex: "#6D28D9")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                .claroGlowShadow()
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)

            Button { onDismiss() } label: {
                Text("Maybe Later")
                    .font(.claroCaption())
                    .foregroundStyle(Color.claroTextMuted)
            }
            .buttonStyle(.plain)
        }
    }

    private var allCleanButton: some View {
        Button { onDismiss() } label: {
            Text("Done")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.claroViolet)
                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func toggle(_ cat: CleanCategory) {
        if selected.contains(cat) { selected.remove(cat) } else { selected.insert(cat) }
    }
}

// MARK: - Scan Category Card

struct ScanCategoryCard: View {
    let icon:       String
    let color:      Color
    let title:      String
    let count:      String
    let detail:     String
    let isSelected: Bool
    var onToggle:   () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? Color.claroViolet : Color.clear)
                        .frame(width: 26, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(
                                    isSelected ? Color.claroViolet : Color.claroTextMuted.opacity(0.4),
                                    lineWidth: 1.5
                                )
                        )
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                // Category icon
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 11))

                // Labels
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.claroHeadline())
                        .foregroundStyle(Color.claroTextPrimary)
                    Text(count)
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroTextSecondary)
                }

                Spacer()

                // Size badge
                Text(detail)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(16)
            .background(isSelected ? Color.claroViolet.opacity(0.07) : Color.claroCard)
            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ClaroRadius.md)
                    .strokeBorder(
                        isSelected ? Color.claroViolet.opacity(0.4) : Color.claroCardBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScanResultsView(
        results: ScanResults(
            photoGroups:   [[], [], []],
            contactGroups: [[], []],
            reclaimableGB: 3.4
        ),
        onDismiss: {}
    )
    .environment(StoreKitService())
    .background(Color.claroBg)
}
