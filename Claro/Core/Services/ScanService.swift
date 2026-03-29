import Photos
import Contacts
import Foundation
import SwiftUI
import Observation


// MARK: - Results Model

struct ScanResults {
    var photoGroups:        [[PHAsset]]   = []
    var contactGroups:      [[CNContact]] = []
    var reclaimableGB:      Double        = 0
    var largeMediaCount:    Int           = 0
    var largeMediaGB:       Double        = 0

    var duplicatePhotoCount:   Int { photoGroups.flatMap   { $0.dropFirst() }.count }
    var duplicateContactCount: Int { contactGroups.flatMap { $0.dropFirst() }.count }
    var isEmpty: Bool {
        duplicatePhotoCount == 0 && duplicateContactCount == 0 && largeMediaCount == 0
    }
}

// MARK: - ScanService

@Observable
final class ScanService {

    // MARK: - Phase

    enum Phase {
        case idle
        case scanning(stage: Stage, progress: Double)
        case done
        case failed(String)
    }

    // MARK: - Stage

    enum Stage: String, CaseIterable, Equatable {
        case photos   = "Scanning Photos"
        case contacts = "Scanning Contacts"
        case storage  = "Analyzing Storage"

        var icon: String {
            switch self {
            case .photos:   return "photo.stack.fill"
            case .contacts: return "person.2.fill"
            case .storage:  return "internaldrive.fill"
            }
        }

        var color: Color {
            switch self {
            case .photos:   return .claroVioletLight
            case .contacts: return .claroCyan
            case .storage:  return .claroGold
            }
        }

        var index: Int { Stage.allCases.firstIndex(of: self) ?? 0 }
    }

    // MARK: - State

    private(set) var phase:             Phase        = .idle
    private(set) var stageProgress:     Double       = 0
    private(set) var currentStageIndex: Int          = 0
    private(set) var results:           ScanResults  = ScanResults()

    // MARK: - Public API

    @MainActor
    func startScan(
        photoAccess:    Bool,
        contactAccess:  Bool,
        photoService:   DuplicatePhotoService,
        iCloudService:  ICloudService,
        contactService: ContactService
    ) async {
        results = ScanResults()

        // ── Stage 1: Photos ──────────────────────────────────────────────
        await enter(.photos)
        if photoAccess {
            await photoService.scan()
        }
        results.photoGroups   = photoService.groups.map { $0.assets }
        results.reclaimableGB = Double(photoService.reclaimableBytes) / 1_073_741_824

        // ── Stage 2: Contacts ────────────────────────────────────────────
        await enter(.contacts)
        if contactAccess {
            await contactService.scan()
        }
        results.contactGroups = contactService.groups.map { $0.contacts }

        // ── Stage 3: Large media (iCloud Manager) ────────────────────────
        await enter(.storage)
        if photoAccess {
            await iCloudService.scan()
        }
        results.largeMediaCount = iCloudService.items.count
        results.largeMediaGB    = Double(iCloudService.totalBytes) / 1_073_741_824
        try? await Task.sleep(nanoseconds: 400_000_000)

        phase = .done
    }

    // MARK: - Helpers

    @MainActor
    private func enter(_ stage: Stage) async {
        phase             = .scanning(stage: stage, progress: 0)
        stageProgress     = 0
        currentStageIndex = stage.index
        // Small delay so the UI can render the stage transition
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    private var currentStage: Stage {
        Stage.allCases[min(currentStageIndex, Stage.allCases.count - 1)]
    }

}
