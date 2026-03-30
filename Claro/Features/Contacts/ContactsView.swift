import SwiftUI
import Contacts

struct ContactsView: View {
    @Environment(PermissionsService.self) private var permissions

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                switch permissions.contactStatus {
                case .notDetermined:
                    PermissionRequestView(
                        icon: "person.2.fill",
                        iconColor: .claroGold,
                        title: "Contact Cleaner",
                        description: "Grant Claro access to your contacts to detect duplicates and merge incomplete records.",
                        buttonTitle: "Grant Access"
                    ) {
                        Task { await permissions.requestContactAccess() }
                    }

                case .denied, .restricted:
                    PermissionDeniedView(
                        icon: "person.2.fill",
                        iconColor: .claroGold,
                        title: "Access Required",
                        description: "Contact access was denied. Please enable it in Settings to use the Contact Cleaner."
                    ) {
                        permissions.openSettings()
                    }

                case .authorized, .limited:
                    ContactsContentView()

                @unknown default:
                    EmptyView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Contact Cleaner")
                        .font(.claroTitle2())
                        .foregroundStyle(Color.claroTextPrimary)
                }
            }
            .onAppear { permissions.refresh() }
        }
    }
}

// MARK: - Content (after permission granted)

struct ContactsContentView: View {
    @Environment(ContactService.self) private var service
    @State private var showReview       = false
    @State private var showIncomplete   = false
    @State private var showNoName       = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ClaroSpacing.lg) {

                summaryCard.padding(.horizontal)

                if service.scanComplete {
                    VStack(spacing: ClaroSpacing.sm) {
                        ClaroSectionLabel(title: "By Category").padding(.horizontal)

                        ClaroToolRow(
                            icon: "person.2.fill",
                            iconColor: .claroDanger,
                            title: "Duplicate Contacts",
                            subtitle: service.groupCount > 0
                                ? "\(service.groupCount) groups · \(service.totalDuplicates) to remove"
                                : "No duplicates found"
                        ) { if service.groupCount > 0 { showReview = true } }
                        .padding(.horizontal)

                        ClaroToolRow(
                            icon: "person.crop.circle.badge.exclamationmark",
                            iconColor: .claroWarning,
                            title: "Incomplete Contacts",
                            subtitle: service.incompleteCount > 0
                                ? "\(service.incompleteCount) contacts missing phone & email"
                                : "All contacts look complete"
                        ) { if service.incompleteCount > 0 { showIncomplete = true } }
                        .padding(.horizontal)

                        ClaroToolRow(
                            icon: "person.crop.circle.badge.xmark",
                            iconColor: .claroTextMuted,
                            title: "No Name Contacts",
                            subtitle: service.noNameCount > 0
                                ? "\(service.noNameCount) contacts with no name"
                                : "All contacts have names"
                        ) { if service.noNameCount > 0 { showNoName = true } }
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: ClaroSpacing.xxl)
            }
            .padding(.top, ClaroSpacing.md)
        }
        .sheet(isPresented: $showReview) {
            ContactReviewView(service: service)
        }
        .sheet(isPresented: $showIncomplete) {
            SimpleContactListView(
                title: "Incomplete Contacts",
                subtitle: "These contacts have a name but no phone number or email.",
                contacts: service.incompleteContacts,
                service: service
            )
        }
        .sheet(isPresented: $showNoName) {
            SimpleContactListView(
                title: "No Name Contacts",
                subtitle: "These contacts have no name, phone, or email assigned.",
                contacts: service.noNameContacts,
                service: service
            )
        }
        .task { await service.scan() }
        .onAppear {
            if service.pendingReview {
                service.pendingReview = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showReview = true
                }
            }
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1F1500"), Color(hex: "#0A0E1A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.claroGold.opacity(0.25))
                .frame(width: 160, height: 160)
                .blur(radius: 60)
                .offset(x: 80, y: -30)

            VStack(spacing: ClaroSpacing.sm) {
                if service.isScanning {
                    VStack(spacing: ClaroSpacing.md) {
                        ProgressView()
                            .tint(Color.claroGold)
                            .scaleEffect(1.4)
                        Text("Scanning contacts…")
                            .font(.claroTitle2())
                            .foregroundStyle(.white)
                        Text("Finding duplicate entries")
                            .font(.claroCaption())
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .padding(ClaroSpacing.xl)

                } else if service.scanComplete && service.groupCount == 0 {
                    VStack(spacing: ClaroSpacing.sm) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.claroGold)
                        Text("All Clean!")
                            .font(.claroTitle2())
                            .foregroundStyle(.white)
                        Text("No duplicate contacts found")
                            .font(.claroCaption())
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .padding(ClaroSpacing.xl)

                } else {
                    Image(systemName: "person.2.badge.gearshape.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.claroGold)

                    Text("\(service.groupCount) duplicate groups found")
                        .font(.claroTitle2())
                        .foregroundStyle(.white)

                    Text("\(service.totalDuplicates) contacts can be removed")
                        .font(.claroCaption())
                        .foregroundStyle(Color.white.opacity(0.55))

                    Button { showReview = true } label: {
                        Text("Review Contacts")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 13)
                            .background(
                                LinearGradient(
                                    colors: [.claroGold, Color(hex: "#D97706")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                            .claroGlowShadow(color: .claroGold)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .disabled(service.groupCount == 0)
                }
            }
            .padding(ClaroSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.lg)
                .strokeBorder(Color.claroGold.opacity(0.25), lineWidth: 1)
        )
        .frame(minHeight: 180)
        .claroCardShadow()
    }
}

// MARK: - Simple Contact List (Incomplete / No Name)

struct SimpleContactListView: View {
    let title:    String
    let subtitle: String
    let contacts: [CNContact]
    let service:  ContactService

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                if contacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.claroSuccess)
                        Text("All Clean!")
                            .font(.claroTitle2())
                            .foregroundStyle(Color.claroTextPrimary)
                    }
                } else {
                    VStack(spacing: 0) {
                        Text(subtitle)
                            .font(.claroCaption())
                            .foregroundStyle(Color.claroTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                        List {
                            ForEach(contacts, id: \.identifier) { contact in
                                let name = fullName(contact)
                                HStack(spacing: 14) {
                                    // Selection circle
                                    Image(systemName: selected.contains(contact.identifier)
                                          ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(selected.contains(contact.identifier)
                                                         ? Color.claroDanger : Color.claroTextMuted)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(name.isEmpty ? "Unknown" : name)
                                            .font(.claroHeadline())
                                            .foregroundStyle(Color.claroTextPrimary)
                                        if !contact.phoneNumbers.isEmpty {
                                            Text(contact.phoneNumbers.first?.value.stringValue ?? "")
                                                .font(.claroCaption())
                                                .foregroundStyle(Color.claroTextSecondary)
                                        } else if !contact.emailAddresses.isEmpty {
                                            Text(contact.emailAddresses.first?.value as? String ?? "")
                                                .font(.claroCaption())
                                                .foregroundStyle(Color.claroTextSecondary)
                                        } else {
                                            Text("No phone or email")
                                                .font(.claroCaption())
                                                .foregroundStyle(Color.claroTextMuted)
                                        }
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selected.contains(contact.identifier) {
                                        selected.remove(contact.identifier)
                                    } else {
                                        selected.insert(contact.identifier)
                                    }
                                }
                                .listRowBackground(Color.claroCard)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)

                        if !selected.isEmpty {
                            Button {
                                Task { await deleteSelected() }
                            } label: {
                                HStack(spacing: 8) {
                                    if isDeleting {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "trash.fill")
                                        Text("Delete \(selected.count) Contacts")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.claroDanger)
                                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                            }
                            .buttonStyle(.plain)
                            .disabled(isDeleting)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.claroViolet)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selected.count == contacts.count ? "Deselect All" : "Select All") {
                        if selected.count == contacts.count {
                            selected.removeAll()
                        } else {
                            selected = Set(contacts.map(\.identifier))
                        }
                    }
                    .foregroundStyle(Color.claroViolet)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func fullName(_ c: CNContact) -> String {
        [c.givenName, c.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func deleteSelected() async {
        isDeleting = true
        let toDelete = contacts.filter { selected.contains($0.identifier) }
        do {
            try await service.deleteContacts(toDelete)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}

#Preview { ContactsView() }
