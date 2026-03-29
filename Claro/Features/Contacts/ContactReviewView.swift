import SwiftUI
import Contacts

struct ContactReviewView: View {
    let service: ContactService
    @Environment(\.dismiss) private var dismiss

    @State private var keepMap:    [UUID: Int]   = [:]   // groupID → index to keep
    @State private var isMerging   = false
    @State private var mergeError: String?

    // Default: keep first contact in each group
    private func keepIndex(for group: ContactDuplicateGroup) -> Int {
        keepMap[group.id] ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.claroBg.ignoresSafeArea()

                if service.groups.isEmpty {
                    allCleanView
                } else {
                    groupList
                    if !service.groups.isEmpty { actionBar }
                }
            }
            .navigationTitle("Duplicate Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.claroGold)
                }
            }
            .alert("Error", isPresented: .constant(mergeError != nil)) {
                Button("OK") { mergeError = nil }
            } message: { Text(mergeError ?? "") }
        }
    }

    // MARK: - Group list

    private var groupList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: ClaroSpacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(service.groupCount) duplicate groups found")
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroTextMuted)
                    InfoNote(text: "Tap a contact to mark it as the one to KEEP. Claro will merge unique phone numbers and emails from the others into it, then delete the duplicates.")
                }
                .padding(.horizontal)
                .padding(.top, ClaroSpacing.sm)

                ForEach(service.groups) { group in
                    ContactGroupCard(
                        group:     group,
                        keepIndex: keepIndex(for: group)
                    ) { newIndex in
                        keepMap[group.id] = newIndex
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 100)
            }
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)
            Button {
                Task { await mergeAll() }
            } label: {
                HStack(spacing: 8) {
                    if isMerging {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.triangle.merge")
                    }
                    Text(isMerging
                         ? "Merging…"
                         : "Merge \(service.groupCount) groups · remove \(service.totalDuplicates) duplicates")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.claroGold, Color(hex: "#D97706")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                .claroGlowShadow(color: .claroGold)
            }
            .buttonStyle(.plain)
            .disabled(isMerging)
            .padding(.horizontal)
            .padding(.vertical, ClaroSpacing.md)
            .background(Color.claroBg)
        }
    }

    // MARK: - All clean

    private var allCleanView: some View {
        VStack(spacing: ClaroSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.claroGold)
            VStack(spacing: 8) {
                Text("All Clean!")
                    .font(.claroTitle())
                    .foregroundStyle(Color.claroTextPrimary)
                Text("No duplicate contacts found.")
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
            }
            Button("Done") { dismiss() }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 15)
                .background(Color.claroGold)
                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                .claroGlowShadow(color: .claroGold)
            Spacer()
        }
    }

    // MARK: - Actions

    private func mergeAll() async {
        isMerging = true
        // Process a snapshot so the list can shrink during iteration
        let snapshot = service.groups
        for group in snapshot {
            let idx = keepMap[group.id] ?? 0
            do {
                try await service.merge(group: group, keepIndex: idx)
            } catch {
                mergeError = error.localizedDescription
                isMerging  = false
                return
            }
        }
        isMerging = false
        if service.groups.isEmpty { dismiss() }
    }
}

// MARK: - Group Card

private struct ContactGroupCard: View {
    let group:      ContactDuplicateGroup
    let keepIndex:  Int
    let onSelect:   (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ClaroSpacing.sm) {
            // Reason label
            HStack(spacing: 6) {
                Image(systemName: group.reason == .duplicatePhone ? "phone.fill" : "person.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.claroGold)
                Text(group.reason == .duplicatePhone ? "Same Phone Number" : "Same Name")
                    .font(.claroLabel())
                    .foregroundStyle(Color.claroGold)
                    .textCase(.uppercase)
                    .kerning(1)
            }
            .padding(.horizontal, 4)

            // Contact rows
            ForEach(Array(group.contacts.enumerated()), id: \.element.identifier) { idx, contact in
                ContactRow(
                    contact:    contact,
                    isSelected: idx == keepIndex
                ) { onSelect(idx) }
            }
        }
        .padding(ClaroSpacing.md)
        .background(Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.md)
                .strokeBorder(Color.claroCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Contact Row

private struct ContactRow: View {
    let contact:    CNContact
    let isSelected: Bool
    let onTap:      () -> Void

    private var displayName: String {
        let full = "\(contact.givenName) \(contact.familyName)"
            .trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? "No Name" : full
    }

    private var primaryPhone: String? {
        contact.phoneNumbers.first?.value.stringValue
    }

    private var primaryEmail: String? {
        contact.emailAddresses.first?.value as String?
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox / keep indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? Color.claroGold : Color.clear)
                        .frame(width: 26, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(
                                    isSelected ? Color.claroGold : Color.claroTextMuted.opacity(0.4),
                                    lineWidth: 1.5
                                )
                        )
                    if isSelected {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                // Avatar placeholder
                ZStack {
                    Circle()
                        .fill(Color.claroGold.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Text(String(displayName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.claroGold)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.claroHeadline())
                        .foregroundStyle(Color.claroTextPrimary)
                    if let phone = primaryPhone {
                        Text(phone)
                            .font(.claroCaption())
                            .foregroundStyle(Color.claroTextSecondary)
                    } else if let email = primaryEmail {
                        Text(email)
                            .font(.claroCaption())
                            .foregroundStyle(Color.claroTextSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Text("KEEP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.claroGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.claroGold.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(isSelected ? Color.claroGold.opacity(0.07) : Color.claroBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? Color.claroGold.opacity(0.35) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
