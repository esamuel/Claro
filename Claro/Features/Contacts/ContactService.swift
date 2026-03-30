import Contacts
import Observation

// MARK: - Model

struct ContactDuplicateGroup: Identifiable {
    let id        = UUID()
    let contacts: [CNContact]
    let reason:   Reason

    enum Reason {
        case duplicatePhone, duplicateName
    }
}

// MARK: - Service

@Observable
final class ContactService {

    // MARK: - State

    private(set) var groups:              [ContactDuplicateGroup] = []
    private(set) var incompleteContacts:  [CNContact]             = []
    private(set) var noNameContacts:      [CNContact]             = []
    private(set) var isScanning           = false
    private(set) var scanComplete         = false

    /// Set to true by Smart Clean to trigger the review sheet when Contacts tab appears.
    var pendingReview = false

    // MARK: - Computed

    var totalDuplicates:  Int { groups.flatMap { $0.contacts.dropFirst() }.count }
    var groupCount:       Int { groups.count }
    var incompleteCount:  Int { incompleteContacts.count }
    var noNameCount:      Int { noNameContacts.count }

    // MARK: - Scan

    @MainActor
    func scan() async {
        guard !isScanning else { return }
        isScanning   = true
        scanComplete = false

        let (found, incomplete, noName) = await Task.detached(priority: .userInitiated) {
            Self.findAllIssues()
        }.value

        groups             = found
        incompleteContacts = incomplete
        noNameContacts     = noName
        isScanning         = false
        scanComplete       = true
    }

    // MARK: - Delete

    /// Deletes the given contacts from the store and rescans.
    @MainActor
    func delete(_ contacts: [CNContact]) async throws {
        let store = CNContactStore()
        let save  = CNSaveRequest()
        for c in contacts {
            save.delete(c.mutableCopy() as! CNMutableContact)
        }
        try store.execute(save)
        await scan()
    }

    // MARK: - Merge

    /// Keeps `keepIndex` contact in the group, merges unique phones/emails from the
    /// others into it, then deletes the duplicates. Rescans on completion.
    @MainActor
    func merge(group: ContactDuplicateGroup, keepIndex: Int) async throws {
        let contacts = group.contacts
        guard keepIndex < contacts.count else { return }

        let keep    = contacts[keepIndex]
        let discard = contacts.indices.filter { $0 != keepIndex }.map { contacts[$0] }

        let merged = keep.mutableCopy() as! CNMutableContact

        // Merge unique phone numbers
        let existingPhones = Set(merged.phoneNumbers.map { $0.value.stringValue })
        for c in discard {
            for ph in c.phoneNumbers where !existingPhones.contains(ph.value.stringValue) {
                merged.phoneNumbers.append(ph)
            }
        }

        // Merge unique email addresses
        let existingEmails = Set(merged.emailAddresses.map { $0.value as String })
        for c in discard {
            for em in c.emailAddresses where !existingEmails.contains(em.value as String) {
                merged.emailAddresses.append(em)
            }
        }

        let store = CNContactStore()
        let save  = CNSaveRequest()
        save.update(merged)
        for c in discard {
            save.delete(c.mutableCopy() as! CNMutableContact)
        }
        try store.execute(save)
        await scan()
    }

    // MARK: - Delete (incomplete / no-name contacts)

    @MainActor
    func deleteContacts(_ contacts: [CNContact]) async throws {
        let store = CNContactStore()
        let save  = CNSaveRequest()
        for c in contacts {
            save.delete(c.mutableCopy() as! CNMutableContact)
        }
        try store.execute(save)
        await scan()
    }

    // MARK: - Detection (off main thread)

    private static func findAllIssues() -> ([ContactDuplicateGroup], [CNContact], [CNContact]) {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey        as CNKeyDescriptor,
            CNContactFamilyNameKey       as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey     as CNKeyDescriptor,
            CNContactEmailAddressesKey   as CNKeyDescriptor,
        ]

        var all: [CNContact] = []
        let req = CNContactFetchRequest(keysToFetch: keys)
        try? store.enumerateContacts(with: req) { c, _ in all.append(c) }

        // ── Duplicates ──────────────────────────────────────────────────────
        var byPhone: [String: [CNContact]] = [:]
        var byName:  [String: [CNContact]] = [:]

        for c in all {
            for ph in c.phoneNumbers {
                let n = ph.value.stringValue.filter(\.isNumber)
                if n.count >= 7 { byPhone[n, default: []].append(c) }
            }
            let name = "\(c.givenName) \(c.familyName)"
                .lowercased().trimmingCharacters(in: .whitespaces)
            if name.count > 2 { byName[name, default: []].append(c) }
        }

        var processedIDs = Set<String>()
        var groups: [ContactDuplicateGroup] = []

        func addGroup(_ contacts: [CNContact], reason: ContactDuplicateGroup.Reason) {
            let ids = contacts.map(\.identifier)
            guard !ids.contains(where: { processedIDs.contains($0) }) else { return }
            var seen   = Set<String>()
            let unique = contacts.filter { seen.insert($0.identifier).inserted }
            guard unique.count > 1 else { return }
            ids.forEach { processedIDs.insert($0) }
            groups.append(ContactDuplicateGroup(contacts: unique, reason: reason))
        }

        byPhone.values.filter { $0.count > 1 }.forEach { addGroup($0, reason: .duplicatePhone) }
        byName.values.filter  { $0.count > 1 }.forEach { addGroup($0, reason: .duplicateName)  }

        // ── Incomplete: has a name but no phone AND no email ─────────────────
        let incomplete = all.filter { c in
            let hasName  = !c.givenName.isEmpty || !c.familyName.isEmpty
            let hasPhone = !c.phoneNumbers.isEmpty
            let hasEmail = !c.emailAddresses.isEmpty
            return hasName && !hasPhone && !hasEmail
        }

        // ── No Name: missing given, family AND organisation name ─────────────
        let noName = all.filter { c in
            c.givenName.isEmpty && c.familyName.isEmpty && c.organizationName.isEmpty
        }

        return (groups, incomplete, noName)
    }
}
