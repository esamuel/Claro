import Foundation
import Observation

// MARK: - Model

struct EmailReputation: Decodable {
    let email:      String
    let reputation: String   // "high" | "medium" | "low" | "none"
    let suspicious: Bool
    let references: Int
    let details:    Details

    struct Details: Decodable {
        let credentialsLeaked:       Bool
        let credentialsLeakedRecent: Bool
        let dataBreach:              Bool
        let blacklisted:             Bool
        let maliciousActivity:       Bool
        let disposable:              Bool
        let freeProvider:            Bool
        let firstSeen:               String?
        let lastSeen:                String?

        enum CodingKeys: String, CodingKey {
            case credentialsLeaked       = "credentials_leaked"
            case credentialsLeakedRecent = "credentials_leaked_recent"
            case dataBreach              = "data_breach"
            case blacklisted
            case maliciousActivity       = "malicious_activity"
            case disposable
            case freeProvider            = "free_provider"
            case firstSeen               = "first_seen"
            case lastSeen                = "last_seen"
        }
    }

    var riskLevel: RiskLevel {
        if details.credentialsLeaked || details.blacklisted || details.maliciousActivity { return .high }
        if details.dataBreach || suspicious || reputation == "low"                        { return .medium }
        return .low
    }

    enum RiskLevel { case high, medium, low }
}

// MARK: - Service

@Observable
final class EmailCheckerService {

    enum CheckState {
        case idle
        case checking
        case result(EmailReputation)
        case error(String)
    }

    private(set) var state: CheckState = .idle
    var email = ""

    var isValidEmail: Bool {
        let pattern = #"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Check

    @MainActor
    func check() async {
        guard isValidEmail else { state = .error("Please enter a valid email address."); return }
        state = .checking

        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        guard let url = URL(string: "https://emailrep.io/\(encoded)") else {
            state = .error("Invalid request.")
            return
        }

        var request        = URLRequest(url: url)
        request.setValue("Claro-iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse

            switch http?.statusCode {
            case 200:
                let rep = try JSONDecoder().decode(EmailReputation.self, from: data)
                state   = .result(rep)
            case 400:
                state = .error("Invalid email address.")
            case 429:
                state = .error("Too many requests. Please wait a moment and try again.")
            default:
                state = .error("Could not reach the server. Check your connection.")
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
        email = ""
    }
}
