import Foundation
import Combine

@MainActor
public final class SettingsViewModel: ObservableObject {
    
    @Published public var isConnected: Bool = false
    @Published public var userProfile: SpotifyUserProfile? = nil
    @Published public var isTestingConnection: Bool = false
    @Published public var connectionTestMessage: String? = nil
    @Published public var isAuthenticating: Bool = false
    @Published public var errorMessage: String? = nil
    
    private let authService = SpotifyAuthService.shared
    private let apiService = SpotifyAPIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        authService.$isAuthenticated
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
            
        authService.$currentUser
            .assign(to: \.userProfile, on: self)
            .store(in: &cancellables)
            
        authService.$isAuthenticating
            .assign(to: \.isAuthenticating, on: self)
            .store(in: &cancellables)
            
        authService.$lastErrorMessage
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
    
    public func login() {
        errorMessage = nil
        Task {
            do {
                try await authService.login()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    public func logout() {
        authService.logout()
        connectionTestMessage = nil
    }
    
    public func testConnection() {
        guard isConnected else {
            errorMessage = "Veuillez d'abord vous connecter à votre compte Spotify."
            return
        }
        
        isTestingConnection = true
        connectionTestMessage = nil
        errorMessage = nil
        
        Task {
            do {
                let (latency, profile) = try await apiService.testConnection()
                self.isTestingConnection = false
                let tier = profile.isPremium ? "Premium 🌟" : "Gratuit"
                self.connectionTestMessage = "✅ Connexion réussie en \(latency) ms !\nCompte : \(profile.displayName ?? "Utilisateur") (\(tier))"
            } catch {
                self.isTestingConnection = false
                self.errorMessage = "Échec du test de connexion : \(error.localizedDescription)"
            }
        }
    }
}
