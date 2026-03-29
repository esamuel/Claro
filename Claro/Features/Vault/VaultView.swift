import SwiftUI
import PhotosUI

// MARK: - VaultView (entry)

struct VaultView: View {
    @Environment(VaultService.self) private var vault

    @State private var unlockError: String?
    @State private var isUnlocking  = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                if vault.isUnlocked {
                    VaultContentView()
                } else {
                    lockScreen
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Private Vault")
                        .font(.claroTitle2())
                        .foregroundStyle(Color.claroTextPrimary)
                }
            }
        }
    }

    // MARK: - Lock Screen

    private var lockScreen: some View {
        VStack(spacing: ClaroSpacing.xl) {
            Spacer()

            // Lock icon
            ZStack {
                Circle()
                    .fill(Color.claroSuccess.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.claroSuccess)
            }

            VStack(spacing: 10) {
                Text("Private Vault")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Color.claroTextPrimary)

                Text("Your photos are encrypted with AES-256\nand stored only on this device.")
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Info note
            infoNote
                .padding(.horizontal, 24)

            Spacer()

            // Unlock button
            VStack(spacing: 14) {
                Button {
                    Task { await unlock() }
                } label: {
                    HStack(spacing: 10) {
                        if isUnlocking {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        } else {
                            Image(systemName: "faceid")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        Text(isUnlocking ? "Authenticating…" : "Unlock Vault")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.claroSuccess)
                    .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                    .claroGlowShadow(color: .claroSuccess)
                }
                .buttonStyle(.plain)
                .disabled(isUnlocking)
                .padding(.horizontal, 24)

                if let err = unlockError {
                    Text(err)
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroDanger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 48)
        }
    }

    private var infoNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.claroSuccess.opacity(0.7))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("How Private Vault works")
                    .font(.claroHeadline())
                    .foregroundStyle(Color.claroTextPrimary)
                Text("Photos you import are encrypted with a unique AES-256 key stored in your iOS Keychain — not in iCloud, not on any server. The key never leaves your device. Even Claro can't read your vault.")
                    .font(.claroCaption())
                    .foregroundStyle(Color.claroTextSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .background(Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.md)
                .strokeBorder(Color.claroSuccess.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func unlock() async {
        isUnlocking = true
        unlockError = nil
        do {
            try await vault.unlock()
        } catch {
            unlockError = error.localizedDescription
        }
        isUnlocking = false
    }
}

// MARK: - Vault Content (unlocked)

private struct VaultContentView: View {
    @Environment(VaultService.self) private var vault

    @State private var pickerItems:         [PhotosPickerItem] = []
    @State private var isImporting          = false
    @State private var importError:         String?
    @State private var selectedItem:        VaultItem?
    @State private var pendingDeleteIDs:    [String] = []
    @State private var showRemoveOriginals  = false
    @State private var itemToDelete:        VaultItem?
    @State private var showGridDeleteConfirm = false

    private let columns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                if vault.items.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 3) {
                        ForEach(vault.items) { item in
                            VaultThumbnailCell(item: item)
                                .onTapGesture { selectedItem = item }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        itemToDelete         = item
                                        showGridDeleteConfirm = true
                                    } label: {
                                        Label("Delete from Vault", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.top, 3)
                }
                Spacer(minLength: 100)
            }

            // Import + Lock bar
            actionBar
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { vault.lock() } label: {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.claroTextSecondary)
                        .padding(8)
                        .background(Color.claroCard)
                        .clipShape(Circle())
                }
            }
        }
        .fullScreenCover(item: $selectedItem) { item in
            VaultImageViewer(item: item)
                .environment(vault)
        }
        .alert("Import Error", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: { Text(importError ?? "") }
        .confirmationDialog(
            "Remove from Photo Library?",
            isPresented: $showRemoveOriginals,
            titleVisibility: .visible
        ) {
            if !pendingDeleteIDs.isEmpty {
                Button("Remove original\(pendingDeleteIDs.count == 1 ? "" : "s") from Photos", role: .destructive) {
                    let ids = pendingDeleteIDs
                    pendingDeleteIDs = []
                    Task { try? await vault.deleteOriginalsFromLibrary(identifiers: ids) }
                }
            }
            Button("Keep in Photos", role: .cancel) { pendingDeleteIDs = [] }
        } message: {
            Text(pendingDeleteIDs.isEmpty
                 ? "The encrypted copy is safe in your Vault. To remove the original, delete it manually from the Photos app."
                 : "The encrypted copy is safe in your Vault. Remove the original from your Photo Library?")
        }
        .confirmationDialog(
            "Delete from Vault?",
            isPresented: $showGridDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete permanently", role: .destructive) {
                if let item = itemToDelete { vault.delete(item) }
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) { itemToDelete = nil }
        } message: {
            Text("This permanently deletes the encrypted copy. The photo will NOT be restored to your Photo Library.")
        }
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await importSelected(newItems) }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: ClaroSpacing.lg) {
            Spacer(minLength: 80)
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(Color.claroSuccess.opacity(0.5))
            VStack(spacing: 6) {
                Text("Vault is empty")
                    .font(.claroTitle())
                    .foregroundStyle(Color.claroTextPrimary)
                Text("Import photos to store them\nencrypted on this device.")
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 80)
        }
        .padding()
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)
            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    HStack(spacing: 8) {
                        if isImporting {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text(isImporting ? "Importing…" : "Import Photos")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.claroSuccess, Color(hex: "#059669")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                    .claroGlowShadow(color: .claroSuccess)
                }
                .disabled(isImporting)

                // Item count badge
                if !vault.items.isEmpty {
                    VStack(spacing: 2) {
                        Text("\(vault.items.count)")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color.claroTextPrimary)
                        Text("items")
                            .font(.claroLabel())
                            .foregroundStyle(Color.claroTextMuted)
                    }
                    .frame(width: 60)
                    .padding(.vertical, 14)
                    .background(Color.claroCard)
                    .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: ClaroRadius.md)
                            .strokeBorder(Color.claroCardBorder, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, ClaroSpacing.md)
            .background(Color.claroBg)
        }
    }

    // MARK: - Import

    @MainActor
    private func importSelected(_ newItems: [PhotosPickerItem]) async {
        isImporting = true
        pickerItems = []

        var importedIdentifiers: [String] = []
        var successCount = 0

        for pickerItem in newItems {
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                    continue
                }
                let name = pickerItem.itemIdentifier ?? UUID().uuidString
                try await vault.importData(data, filename: name)
                successCount += 1

                if let id = pickerItem.itemIdentifier {
                    importedIdentifiers.append(id)
                }
            } catch {
                importError = error.localizedDescription
                break
            }
        }

        isImporting = false

        // Show the remove-originals prompt after any successful import
        if successCount > 0 {
            pendingDeleteIDs    = importedIdentifiers
            showRemoveOriginals = true
        }
    }
}

// MARK: - Thumbnail Cell

private struct VaultThumbnailCell: View {
    let item: VaultItem
    @Environment(VaultService.self) private var vault
    @State private var thumb: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.claroCard

                if let thumb {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo.fill")
                        .foregroundStyle(Color.claroTextMuted.opacity(0.4))
                        .font(.system(size: 24))
                }
            }
            .frame(width: geo.size.width, height: geo.size.width) // square
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .task { thumb = await vault.loadThumbnail(item) }
    }
}

// MARK: - Full-Screen Viewer

struct VaultImageViewer: View {
    let item: VaultItem
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale = max(1, $0) }
                            .onEnded   { _ in withAnimation { scale = 1 } }
                    )
            } else {
                ProgressView().tint(.white)
            }
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { showDeleteConfirm = true } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.claroDanger.opacity(0.9))
                    .padding()
            }
        }
        .confirmationDialog("Delete from Vault?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                vault.delete(item)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes the encrypted copy. The photo will NOT be restored to your Photo Library.")
        }
        .task { image = await vault.loadFullImage(item) }
        .statusBar(hidden: true)
    }
}
