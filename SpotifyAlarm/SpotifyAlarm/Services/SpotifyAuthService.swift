import Foundation
import AuthenticationServices
import CryptoKit
import Combine
import UIKit

/// Erreurs spécifiques à l'authentification Spotify
public enum SpotifyAuthError: LocalizedError {
    case clientIDNotConfigured
    case invalidAuthURL
    case sessionCancelled
    case invalidCallbackURL
    case missingAuthCode
    case tokenExchangeFailed(String)
    case notAuthenticated
    case tokenRefreshFailed
    
    public var errorDescription: String? {
        switch self {
        case .clientIDNotConfigured:
            return "Le Client ID Spotify n'est pas configuré. Veuillez renseigner votre Client ID dans SpotifyConfig.swift."
        case .invalidAuthURL:
            return "Impossible de générer l'URL d'autorisation Spotify."
        case .sessionCancelled:
            return "Connexion annulée par l'utilisateur."
        case .invalidCallbackURL:
            return "URL de redirection Spotify invalide."
        case .missingAuthCode:
            return "Le code d'autorisation Spotify est manquant."
        case .tokenExchangeFailed(let msg):
            return "Échec de l'obtention des jetons : \(msg)"
        case .notAuthenticated:
            return "Spotify n'est pas connecté."
        case .tokenRefreshFailed:
            return "L'autorisation Spotify a expiré. Veuillez vous reconnecter."
        }
    }
}

/// Service d'authentification gérant le flux OAuth 2.0 PKCE sans secret client
@MainActor
public final class SpotifyAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    
    public static let shared = SpotifyAuthService()
    
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: SpotifyUserProfile? = nil
    @Published public var isAuthenticating: Bool = false
    @Published public var lastErrorMessage: String? = nil
    
    private let keychain = KeychainService.shared
    private var codeVerifier: String?
    
    override private init() {
        super.init()
        // Vérification de l'état au démarrage
        if let token = keychain.getAccessToken(), !token.isEmpty {
            self.isAuthenticated = true
            Task {
                await refreshUserProfile()
            }
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    nonisolated public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if Thread.isMainThread {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            return windowScene?.windows.first(where: { $0.isKeyWindow }) ?? UIWindow()
        } else {
            return DispatchQueue.main.sync {
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                return windowScene?.windows.first(where: { $0.isKeyWindow }) ?? UIWindow()
            }
        }
    }
    
    // MARK: - Flux de Connexion PKCE
    
    /// Démarre le flux d'autorisation OAuth PKCE
    public func login() async throws {
        guard SpotifyConfig.isConfigured else {
            let error = SpotifyAuthError.clientIDNotConfigured
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
        
        isAuthenticating = true
        lastErrorMessage = nil
        defer { isAuthenticating = false }
        
        // 1. Génération du code_verifier et code_challenge (RFC 7636)
        let verifier = generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)
        let state = UUID().uuidString
        
        // 2. Construction de l'URL d'autorisation
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: SpotifyConfig.scopes),
            URLQueryItem(name: "state", value: state)
        ]
        
        guard let authURL = components?.url else {
            throw SpotifyAuthError.invalidAuthURL
        }
        
        // 3. Présentation de ASWebAuthenticationSession
        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "spotifyalarm"
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: SpotifyAuthError.sessionCancelled)
                    return
                }
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: SpotifyAuthError.invalidCallbackURL)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            
            session.presentationContextProvider = self
            // Permet de réutiliser les cookies Safari si déjà connecté sur Spotify Web
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
        
        // 4. Extraction du code d'autorisation
        guard let urlComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let queryItems = urlComponents.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw SpotifyAuthError.missingAuthCode
        }
        
        // 5. Échange du code contre les jetons d'accès
        try await exchangeCodeForTokens(code: code, verifier: verifier)
        
        // 6. Récupération des informations de profil
        await refreshUserProfile()
    }
    
    /// Déconnexion complète
    public func logout() {
        keychain.clearAllTokens()
        self.isAuthenticated = false
        self.currentUser = nil
        self.lastErrorMessage = nil
    }
    
    /// Récupère un token d'accès valide, avec rafraîchissement transparent si nécessaire
    public func getValidAccessToken() async throws -> String {
        guard let _ = keychain.getAccessToken() else {
            throw SpotifyAuthError.notAuthenticated
        }
        
        if keychain.isTokenExpired() {
            try await refreshAccessToken()
        }
        
        guard let validToken = keychain.getAccessToken() else {
            throw SpotifyAuthError.notAuthenticated
        }
        return validToken
    }
    
    // MARK: - Échange de Jetons (Token Exchange)
    
    private func exchangeCodeForTokens(code: String, verifier: String) async throws {
        guard let tokenURL = URL(string: "https://accounts.spotify.com/api/token") else { return }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParameters = [
            "grant_type": "authorization_code",
            "client_id": SpotifyConfig.clientID,
            "code": code,
            "redirect_uri": SpotifyConfig.redirectURI,
            "code_verifier": verifier
        ]
        
        request.httpBody = bodyParameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyAuthError.tokenExchangeFailed("Réponse réseau invalide")
        }
        
        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Erreur HTTP \(httpResponse.statusCode)"
            throw SpotifyAuthError.tokenExchangeFailed(errorText)
        }
        
        let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        keychain.saveAccessToken(tokenResponse.accessToken)
        if let refreshToken = tokenResponse.refreshToken {
            keychain.saveRefreshToken(refreshToken)
        }
        keychain.saveTokenExpiration(expiresInSeconds: tokenResponse.expiresIn)
        
        self.isAuthenticated = true
    }
    
    /// Rafraîchissement automatique du token expiré
    private func refreshAccessToken() async throws {
        guard let refreshToken = keychain.getRefreshToken() else {
            logout()
            throw SpotifyAuthError.tokenRefreshFailed
        }
        
        guard let tokenURL = URL(string: "https://accounts.spotify.com/api/token") else { return }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": SpotifyConfig.clientID
        ]
        
        request.httpBody = bodyParameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logout()
                throw SpotifyAuthError.tokenRefreshFailed
            }
            
            let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            keychain.saveAccessToken(tokenResponse.accessToken)
            if let newRefresh = tokenResponse.refreshToken {
                keychain.saveRefreshToken(newRefresh)
            }
            keychain.saveTokenExpiration(expiresInSeconds: tokenResponse.expiresIn)
        } catch {
            logout()
            throw SpotifyAuthError.tokenRefreshFailed
        }
    }
    
    // MARK: - Profil Utilisateur
    
    public func refreshUserProfile() async {
        do {
            let token = try await getValidAccessToken()
            guard let url = URL(string: "https://api.spotify.com/v1/me") else { return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let profile = try JSONDecoder().decode(SpotifyUserProfile.self, from: data)
                self.currentUser = profile
                self.isAuthenticated = true
            }
        } catch {
            print("Erreur de récupération profil Spotify: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Générateurs Cryptographiques PKCE
    
    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
