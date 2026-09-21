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
    case parsingError(String? = nil)
    
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
        case .parsingError(let detail):
            if let detail = detail, !detail.isEmpty {
                return "Impossible de traiter la réponse reçue de Spotify (\(detail))."
            }
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
        
        var components = URLComponents(string: "https://api.spotify.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: cleanQuery),
            URLQueryItem(name: "type", value: types.map { $0.rawValue }.joined(separator: ",")),
            URLQueryItem(name: "limit", value: "10")
        ]
        
        guard let url = components?.url else {
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
                for trackWrap in tracks {
                    guard let track = trackWrap?.value,
                          let id = track.id,
                          let name = track.name,
                          let uri = track.uri,
                          !id.isEmpty else { continue }
                    
                    let artists = track.artists?
                        .compactMap { $0?.name }
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ") ?? "Artiste inconnu"
                    
                    let image = track.album?.images?
                        .compactMap { $0?.url }
                        .first(where: { !$0.isEmpty })
                    
                    items.append(SpotifyTrackItem(
                        id: id,
                        name: name,
                        artistName: artists.isEmpty ? "Artiste inconnu" : artists,
                        albumName: track.album?.name,
                        imageUrl: image,
                        uri: uri,
                        type: .track
                    ))
                }
            }
            
            // 2. Playlists
            if let playlists = searchResult.playlists?.items {
                for plWrap in playlists {
                    guard let pl = plWrap?.value,
                          let id = pl.id,
                          let name = pl.name,
                          let uri = pl.uri,
                          !id.isEmpty else { continue }
                    
                    let owner = pl.owner?.displayName ?? "Spotify"
                    let image = pl.images?
                        .compactMap { $0?.url }
                        .first(where: { !$0.isEmpty })
                    
                    items.append(SpotifyTrackItem(
                        id: id,
                        name: name,
                        artistName: "Playlist de \(owner)",
                        albumName: pl.description,
                        imageUrl: image,
                        uri: uri,
                        type: .playlist
                    ))
                }
            }
            
            // 3. Albums
            if let albums = searchResult.albums?.items {
                for albWrap in albums {
                    guard let alb = albWrap?.value,
                          let id = alb.id,
                          let name = alb.name,
                          let uri = alb.uri,
                          !id.isEmpty else { continue }
                    
                    let artists = alb.artists?
                        .compactMap { $0?.name }
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ") ?? "Artiste"
                    
                    let image = alb.images?
                        .compactMap { $0?.url }
                        .first(where: { !$0.isEmpty })
                    
                    items.append(SpotifyTrackItem(
                        id: id,
                        name: name,
                        artistName: "Album de \(artists)",
                        albumName: alb.name,
                        imageUrl: image,
                        uri: uri,
                        type: .album
                    ))
                }
            }
            
            return items
        } catch {
            print("Erreur de décodage recherche: \(error)")
            throw SpotifyAPIError.parsingError(error.localizedDescription)
        }
    }
    
    // MARK: - Playlists Personnelles
    
    public func fetchUserPlaylists() async throws -> [SpotifyTrackItem] {
        let token = try await authService.getValidAccessToken()
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/playlists?limit=20") else {
            throw SpotifyAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SpotifyAPIError.apiError((response as? HTTPURLResponse)?.statusCode ?? 500, "Impossible de récupérer vos playlists")
        }
        
        let playlistsResponse = try JSONDecoder().decode(SpotifyUserPlaylistsResponse.self, from: data)
        return (playlistsResponse.items ?? []).compactMap { plWrap in
            guard let pl = plWrap?.value,
                  let id = pl.id,
                  let name = pl.name,
                  let uri = pl.uri,
                  !id.isEmpty else { return nil }
            let owner = pl.owner?.displayName ?? "Vous"
            let image = pl.images?.compactMap({ $0?.url }).first(where: { !$0.isEmpty })
            return SpotifyTrackItem(
                id: id,
                name: name,
                artistName: "Par \(owner)",
                albumName: pl.description,
                imageUrl: image,
                uri: uri,
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
