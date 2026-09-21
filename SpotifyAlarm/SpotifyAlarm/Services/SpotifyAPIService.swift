import Foundation
import UIKit

/// Erreurs de l'API Spotify
public enum SpotifyAPIError: LocalizedError {
    case invalidURL
    case notConnected
    case noActiveDevice
    case premiumRequired
    case networkError(String)
    case apiError(Int, String)
    case parsingError
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL de requête Spotify invalide."
        case .notConnected:
            return "Spotify n'est pas connecté. Veuillez vous connecter dans les Réglages."
        case .noActiveDevice:
            return "Aucun appareil Spotify actif trouvé. Ouvrez l'application Spotify sur votre iPhone ou connectez un appareil Spotify Connect."
        case .premiumRequired:
            return "La commande de lecture à distance via l'API officielle nécessite un compte Spotify Premium. L'application basculera sur le deep link direct."
        case .networkError(let msg):
            return "Impossible de contacter Spotify : \(msg)"
        case .apiError(let code, let msg):
            return "Erreur Spotify (\(code)) : \(msg)"
        case .parsingError:
            return "Impossible de traiter la réponse reçue de Spotify."
        }
    }
}

/// Service de communication avec l'API Web officielle de Spotify
@MainActor
public final class SpotifyAPIService {
    
    public static let shared = SpotifyAPIService()
    
    private let authService = SpotifyAuthService.shared
    
    private init() {}
    
    // MARK: - Recherche de Musiques, Albums et Playlists
    
    public func search(query: String, types: [SpotifyItemType] = [.track, .album, .playlist]) async throws -> [SpotifyTrackItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return [] }
        
        let token = try await authService.getValidAccessToken()
        
        let typesString = types.map { $0.rawValue }.joined(separator: ",")
        guard let encodedQuery = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=\(typesString)&limit=25") else {
            throw SpotifyAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAPIError.networkError("Pas de réponse HTTP")
        }
        
        guard http.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Code \(http.statusCode)"
            throw SpotifyAPIError.apiError(http.statusCode, errorMsg)
        }
        
        do {
            let searchResult = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
            var items: [SpotifyTrackItem] = []
            
            // 1. Morceaux
            if let tracks = searchResult.tracks?.items {
                for track in tracks {
                    let artists = track.artists?.compactMap { $0.name }.joined(separator: ", ") ?? "Artiste inconnu"
                    let image = track.album?.images?.first?.url
                    items.append(SpotifyTrackItem(
                        id: track.id,
                        name: track.name,
                        artistName: artists,
                        albumName: track.album?.name,
                        imageUrl: image,
                        uri: track.uri,
                        type: .track
                    ))
                }
            }
            
            // 2. Playlists
            if let playlists = searchResult.playlists?.items {
                for pl in playlists {
                    let owner = pl.owner?.displayName ?? "Spotify"
                    let image = pl.images?.first?.url
                    items.append(SpotifyTrackItem(
                        id: pl.id,
                        name: pl.name,
                        artistName: "Playlist de \(owner)",
                        albumName: pl.description,
                        imageUrl: image,
                        uri: pl.uri,
                        type: .playlist
                    ))
                }
            }
            
            // 3. Albums
            if let albums = searchResult.albums?.items {
                for alb in albums {
                    let artists = alb.artists?.compactMap { $0.name }.joined(separator: ", ") ?? "Artiste"
                    let image = alb.images?.first?.url
                    items.append(SpotifyTrackItem(
                        id: alb.id,
                        name: alb.name,
                        artistName: "Album de \(artists)",
                        albumName: alb.name,
                        imageUrl: image,
                        uri: alb.uri,
                        type: .album
                    ))
                }
            }
            
            return items
        } catch {
            print("Erreur de décodage recherche: \(error)")
            throw SpotifyAPIError.parsingError
        }
    }
    
    // MARK: - Playlists Personnelles
    
    public func fetchUserPlaylists() async throws -> [SpotifyTrackItem] {
        let token = try await authService.getValidAccessToken()
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/playlists?limit=30") else {
            throw SpotifyAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SpotifyAPIError.apiError((response as? HTTPURLResponse)?.statusCode ?? 500, "Impossible de récupérer vos playlists")
        }
        
        let playlistsResponse = try JSONDecoder().decode(SpotifyUserPlaylistsResponse.self, from: data)
        return playlistsResponse.items.map { pl in
            SpotifyTrackItem(
                id: pl.id,
                name: pl.name,
                artistName: "Par \(pl.owner?.displayName ?? "Vous")",
                albumName: pl.description,
                imageUrl: pl.images?.first?.url,
                uri: pl.uri,
                type: .playlist
            )
        }
    }
    
    // MARK: - Test de Connexion & Latence
    
    public func testConnection() async throws -> (latencyMs: Int, profile: SpotifyUserProfile) {
        let startTime = DispatchTime.now()
        let token = try await authService.getValidAccessToken()
        
        guard let url = URL(string: "https://api.spotify.com/v1/me") else {
            throw SpotifyAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let endTime = DispatchTime.now()
        let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let latencyMs = Int(Double(nanoTime) / 1_000_000.0)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SpotifyAPIError.apiError((response as? HTTPURLResponse)?.statusCode ?? 500, "Échec du test de connexion")
        }
        
        let profile = try JSONDecoder().decode(SpotifyUserProfile.self, from: data)
        return (latencyMs, profile)
    }
    
    // MARK: - Déclenchement de Lecture (Playback Control)
    
    /// Démarre la lecture via l'API Spotify officielle (nécessite Spotify Premium & appareil actif).
    /// En cas d'indisponibilité, bascule automatiquement sur l'ouverture de l'application native.
    public func triggerPlayback(item: SpotifyTrackItem) async throws {
        // Tentative de lecture Web API
        do {
            try await startWebAPIPlayback(item: item)
        } catch {
            print("Web API playback échouée (\(error.localizedDescription)). Bascule sur le deep link direct.")
            // Basculement sur l'ouverture directe de l'application Spotify
            await MainActor.run {
                self.openSpotifyApp(uri: item.uri)
            }
        }
    }
    
    private func startWebAPIPlayback(item: SpotifyTrackItem) async throws {
        let token = try await authService.getValidAccessToken()
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/play") else {
            throw SpotifyAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any]
        if item.type == .track {
            body = ["uris": [item.uri]]
        } else {
            body = ["context_uri": item.uri]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 204 || http.statusCode == 200 {
                return // Lecture démarrée avec succès
            } else if http.statusCode == 404 {
                throw SpotifyAPIError.noActiveDevice
            } else if http.statusCode == 403 {
                throw SpotifyAPIError.premiumRequired
            } else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Erreur HTTP \(http.statusCode)"
                throw SpotifyAPIError.apiError(http.statusCode, errorMsg)
            }
        }
    }
    
    // MARK: - Deep Link / URL Scheme Spotify
    
    /// Ouvre directement l'application Spotify avec le morceau/playlist
    @MainActor
    public func openSpotifyApp(uri: String) {
        guard let url = URL(string: uri) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            // Repli vers le lien web universel
            let parts = uri.components(separatedBy: ":")
            if parts.count == 3 {
                let type = parts[1]
                let id = parts[2]
                if let webURL = URL(string: "https://open.spotify.com/\(type)/\(id)") {
                    UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
                }
            }
        }
    }
}
