import Foundation
import Security

/// Service de gestion sécurisée des jetons OAuth dans le Keychain iOS.
public final class KeychainService {
    
    public static let shared = KeychainService()
    
    private let serviceName = "com.spotifyalarm.auth"
    
    private enum Keys {
        static let accessToken = "spotify_access_token"
        static let refreshToken = "spotify_refresh_token"
        static let tokenExpiration = "spotify_token_expiration"
    }
    
    private init() {}
    
    // MARK: - Access Token
    
    public func saveAccessToken(_ token: String) {
        save(key: Keys.accessToken, data: Data(token.utf8))
    }
    
    public func getAccessToken() -> String? {
        guard let data = load(key: Keys.accessToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Refresh Token
    
    public func saveRefreshToken(_ token: String) {
        save(key: Keys.refreshToken, data: Data(token.utf8))
    }
    
    public func getRefreshToken() -> String? {
        guard let data = load(key: Keys.refreshToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Expiration Date
    
    public func saveTokenExpiration(expiresInSeconds: Int) {
        let expirationDate = Date().addingTimeInterval(TimeInterval(expiresInSeconds))
        let timestamp = String(expirationDate.timeIntervalSince1970)
        save(key: Keys.tokenExpiration, data: Data(timestamp.utf8))
    }
    
    public func isTokenExpired() -> Bool {
        guard let data = load(key: Keys.tokenExpiration),
              let string = String(data: data, encoding: .utf8),
              let timestamp = Double(string) else {
            return true
        }
        // Considéré comme expiré s'il reste moins de 60 secondes de validité
        return Date().timeIntervalSince1970 >= (timestamp - 60)
    }
    
    // MARK: - Nettoyage Complet
    
    public func clearAllTokens() {
        delete(key: Keys.accessToken)
        delete(key: Keys.refreshToken)
        delete(key: Keys.tokenExpiration)
    }
    
    // MARK: - Méthodes Primitives Keychain
    
    private func save(key: String, data: Data) {
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return data
        }
        return nil
    }
    
    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
