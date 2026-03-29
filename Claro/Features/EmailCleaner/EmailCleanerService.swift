import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security
import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Google OAuth Configuration
//
// Setup (one-time):
//  1. console.cloud.google.com → New Project → Enable "Gmail API"
//  2. APIs & Services → Credentials → Create OAuth Client ID → iOS
//  3. Set Bundle ID: com.samueleskenasy.claro
//  4. Copy the generated Client ID into kClientID below
//  5. Copy the iOS URL scheme (e.g. com.googleusercontent.apps.XXXXXX) into kRedirectScheme
//  6. Add that scheme to project.yml under CFBundleURLSchemes and run xcodegen
// ─────────────────────────────────────────────────────────────────────────────
let kGmailClientID      = "YOUR_CLIENT_ID.apps.googleusercontent.com"
let kGmailRedirectScheme = "com.googleusercontent.apps.YOUR_CLIENT_ID"   // reverse client ID

// MARK: - Models

struct GmailEmailItem: Identifiable {
    let id: String
    let threadId: String
}

// MARK: - Service

@Observable
@MainActor
final class EmailCleanerService {

    // Auth state
    private(set) var isAuthenticated = false
    private(set) var userEmail: String?

    // Scan state
    private(set) var isScanning      = false
    private(set) var scanComplete    = false
    private(set) var errorMessage: String?

    // Categories
    private(set) var newsletters:     [GmailEmailItem] = []
    private(set) var promotions:      [GmailEmailItem] = []
    private(set) var social:          [GmailEmailItem] = []

    private(set) var deletingCategory: String?

    // Tokens
    private var accessToken:  String?
    private var refreshToken: String?

    // Auth session kept alive
    private var authSession: ASWebAuthenticationSession?

    private let keychainService = "com.samueleskenasy.claro.gmail"

    // MARK: - Init (restore session)

    init() {
        if let saved = keychainLoad("access_token") {
            accessToken  = saved
            refreshToken = keychainLoad("refresh_token")
            isAuthenticated = true
            Task { [weak self] in
                await self?.fetchProfile()
                await self?.scan()
            }
        }
    }

    // MARK: - Sign In

    func signIn() async throws {
        let verifier  = codeVerifier()
        let challenge = codeChallenge(verifier)
        let state     = UUID().uuidString

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            URLQueryItem(name: "client_id",            value: kGmailClientID),
            URLQueryItem(name: "redirect_uri",          value: redirectURI),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "scope",                 value: "https://www.googleapis.com/auth/gmail.modify email profile"),
            URLQueryItem(name: "state",                 value: state),
            URLQueryItem(name: "code_challenge",        value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type",           value: "offline"),
            URLQueryItem(name: "prompt",                value: "consent"),
        ]

        let contextProvider = WindowContextProvider()

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(
                url: comps.url!,
                callbackURLScheme: kGmailRedirectScheme
            ) { url, err in
                if let url { cont.resume(returning: url) }
                else       { cont.resume(throwing: err ?? EmailCleanerError.authFailed) }
            }
            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw EmailCleanerError.authFailed }

        try await exchangeCode(code, verifier: verifier)
        await fetchProfile()
        isAuthenticated = true
        await scan()
    }

    // MARK: - Sign Out

    func signOut() {
        accessToken     = nil
        refreshToken    = nil
        isAuthenticated = false
        userEmail       = nil
        newsletters     = []
        promotions      = []
        social          = []
        scanComplete    = false
        keychainDelete("access_token")
        keychainDelete("refresh_token")
    }

    // MARK: - Scan

    func scan() async {
        guard !isScanning else { return }
        isScanning   = true
        scanComplete = false
        errorMessage = nil

        async let nl = fetchIDs(query: "label:inbox has:list-unsubscribe newer_than:90d")
        async let pr = fetchIDs(query: "label:inbox category:promotions newer_than:90d")
        async let sc = fetchIDs(query: "label:inbox category:social newer_than:90d")

        let (nlRes, prRes, scRes) = await (nl, pr, sc)
        newsletters  = nlRes
        promotions   = prRes
        social       = scRes
        isScanning   = false
        scanComplete = true
    }

    // MARK: - Delete

    func deleteAll(category: String) async throws {
        deletingCategory = category
        defer { deletingCategory = nil }

        let ids: [String]
        switch category {
        case "newsletters": ids = newsletters.map { $0.id }
        case "promotions":  ids = promotions.map  { $0.id }
        case "social":      ids = social.map      { $0.id }
        default: return
        }
        guard !ids.isEmpty else { return }

        // Gmail batchDelete is limited to 1000 IDs per call — chunk it
        for chunk in ids.chunked(into: 1000) {
            try await batchDelete(ids: chunk)
        }

        switch category {
        case "newsletters": newsletters = []
        case "promotions":  promotions  = []
        case "social":      social      = []
        default: break
        }
    }

    // MARK: - Gmail REST API

    private func fetchIDs(query: String) async -> [GmailEmailItem] {
        guard let token = await validToken() else { return [] }

        var comps = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        comps.queryItems = [
            URLQueryItem(name: "q",          value: query),
            URLQueryItem(name: "maxResults", value: "500"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _)  = try? await URLSession.shared.data(for: req),
              let response   = try? JSONDecoder().decode(MessageListResponse.self, from: data)
        else { return [] }

        return (response.messages ?? []).map { GmailEmailItem(id: $0.id, threadId: $0.threadId) }
    }

    private func batchDelete(ids: [String]) async throws {
        guard let token = await validToken() else { throw EmailCleanerError.notAuthenticated }

        var req = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/batchDelete")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(BatchDeleteBody(ids: ids))

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 204 else {
            throw EmailCleanerError.deleteFailed
        }
    }

    private func fetchProfile() async {
        guard let token = accessToken else { return }
        var req = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/profile")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        userEmail = json["emailAddress"] as? String
    }

    // MARK: - Token Exchange & Refresh

    private func exchangeCode(_ code: String, verifier: String) async throws {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id":     kGmailClientID,
            "code":          code,
            "redirect_uri":  redirectURI,
            "grant_type":    "authorization_code",
            "code_verifier": verifier,
        ]
        req.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard !token.access_token.isEmpty else { throw EmailCleanerError.authFailed }

        accessToken  = token.access_token
        refreshToken = token.refresh_token ?? refreshToken
        keychainSave("access_token",  value: token.access_token)
        if let r = token.refresh_token { keychainSave("refresh_token", value: r) }
    }

    /// Returns a valid access token, refreshing silently if needed.
    private func validToken() async -> String? {
        if let t = accessToken { return t }
        guard let refresh = refreshToken else { return nil }

        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=\(kGmailClientID)&refresh_token=\(refresh)&grant_type=refresh_token"
        req.httpBody = body.data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let token = try? JSONDecoder().decode(TokenResponse.self, from: data),
              !token.access_token.isEmpty
        else { return nil }

        accessToken = token.access_token
        keychainSave("access_token", value: token.access_token)
        return token.access_token
    }

    // MARK: - PKCE

    private func codeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func codeChallenge(_ verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - URL helpers

    private var redirectURI: String { "\(kGmailRedirectScheme):/oauth2redirect" }

    // MARK: - Keychain

    private func keychainSave(_ key: String, value: String) {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String:   Data(value.utf8),
        ]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    private func keychainLoad(_ key: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(_ key: String) {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(q as CFDictionary)
    }

    // MARK: - Decodable models

    private struct MessageListResponse: Decodable {
        let messages: [MsgRef]?
        struct MsgRef: Decodable { let id: String; let threadId: String }
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int?
    }

    private struct BatchDeleteBody: Encodable {
        let ids: [String]
    }

    // MARK: - Errors

    enum EmailCleanerError: LocalizedError {
        case cancelled, authFailed, notAuthenticated, deleteFailed
        var errorDescription: String? {
            switch self {
            case .cancelled:        return "Sign-in was cancelled."
            case .authFailed:       return "Authentication failed. Verify your Google Client ID."
            case .notAuthenticated: return "Not signed in."
            case .deleteFailed:     return "Could not delete emails. Try again."
            }
        }
    }
}

// MARK: - Array chunking helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

// MARK: - ASWebAuthenticationSession context (non-isolated helper)

private final class WindowContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let window: UIWindow

    override init() {
        window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? UIWindow()
        super.init()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window
    }
}
