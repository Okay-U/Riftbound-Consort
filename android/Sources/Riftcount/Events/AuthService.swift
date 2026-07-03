//
//  AuthService.swift
//  Riftbound Companiokay
//
//  Locator authentication: email/password login (mobile endpoint) and the
//  current-user lookup. Token is returned to the caller; persistence is the
//  AuthSession's job.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Models

struct LocatorLoginResponse: Decodable, Sendable {
    let token: String

    private enum CodingKeys: String, CodingKey { case token, key }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Mobile endpoint returns "token"; web dj-rest-auth uses "key" — accept both.
        if let value = try container.decodeIfPresent(String.self, forKey: .token) {
            token = value
        } else {
            token = try container.decode(String.self, forKey: .key)
        }
    }
}

struct LocatorUser: Decodable, Sendable, Identifiable {
    let id: Int
    let email: String?
    let bestIdentifier: String?
    let firstName: String?
    let lastName: String?

    var displayName: String {
        if let name = bestIdentifier, !name.isEmpty { return name }
        let full = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        if !full.isEmpty { return full }
        return email ?? "Player"
    }
}

// MARK: - Service

protocol AuthService: Sendable {
    func login(email: String, password: String) async throws -> String
    func currentUser(token: String) async throws -> LocatorUser
}

final class RiftboundAuthService: AuthService, @unchecked Sendable {
    private let base = URL(string: "https://api.riftbound.uvsgames.com/api/v2/")!
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func login(email: String, password: String) async throws -> String {
        guard let url = URL(string: "auth/mobile/login/", relativeTo: base) else {
            throw AuthError.network
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = ["email": email, "password": password, "source_app": "phoenix"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.network }
        switch http.statusCode {
        case 200..<300:
            return try decoder.decode(LocatorLoginResponse.self, from: data).token
        case 400, 401, 403:
            throw AuthError.invalidCredentials
        default:
            throw AuthError.server(http.statusCode)
        }
    }

    func currentUser(token: String) async throws -> LocatorUser {
        guard let url = URL(string: "users/self/", relativeTo: base) else {
            throw AuthError.network
        }
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.network }
        switch http.statusCode {
        case 200..<300:
            return try decoder.decode(LocatorUser.self, from: data)
        case 401, 403:
            throw AuthError.tokenExpired
        default:
            throw AuthError.server(http.statusCode)
        }
    }
}

enum AuthError: LocalizedError {
    case network
    case invalidCredentials
    case tokenExpired
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .network:            return "Couldn't reach the login server. Check your connection."
        case .invalidCredentials: return "Wrong email or password."
        case .tokenExpired:       return "Your session expired. Please sign in again."
        case .server(let code):   return "Login server error (\(code))."
        }
    }
}
