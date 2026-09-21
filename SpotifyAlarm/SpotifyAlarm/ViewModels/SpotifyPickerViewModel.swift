import Foundation
import Combine

public enum PickerTab: String, CaseIterable, Identifiable {
    case search = "Recherche"
    case playlists = "Mes Playlists"
    
    public var id: String { rawValue }
}

@MainActor
public final class SpotifyPickerViewModel: ObservableObject {
    
    @Published public var searchQuery: String = ""
    @Published public var selectedTab: PickerTab = .search
    @Published public var searchResults: [SpotifyTrackItem] = []
    @Published public var userPlaylists: [SpotifyTrackItem] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    private let apiService = SpotifyAPIService.shared
    private let authService = SpotifyAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>? = nil
    
    public init() {
        setupSearchDebounce()
    }
    
    public var isConnected: Bool {
        return authService.isAuthenticated
    }
    
    private func setupSearchDebounce() {
        $searchQuery
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    public func performSearch(query: String) {
        searchTask?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isLoading = false
            return
        }
        
        guard isConnected else {
            errorMessage = "Connectez-vous à Spotify dans les Réglages pour chercher des musiques."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        searchTask = Task {
            do {
                let items = try await apiService.search(query: trimmed)
                if !Task.isCancelled {
                    self.searchResults = items
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    public func loadUserPlaylists() {
        guard isConnected else {
            errorMessage = "Connectez-vous à Spotify dans les Réglages pour voir vos playlists."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let playlists = try await apiService.fetchUserPlaylists()
                self.userPlaylists = playlists
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
