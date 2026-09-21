import Foundation

/// Type d'élément musical Spotify
public enum SpotifyItemType: String, Codable, CaseIterable {
    case track = "track"
    case album = "album"
    case playlist = "playlist"
    
    public var label: String {
        switch self {
        case .track: return "Morceau"
        case .album: return "Album"
        case .playlist: return "Playlist"
        }
    }
    
    public var iconName: String {
        switch self {
        case .track: return "music.note"
        case .album: return "opticaldisc"
        case .playlist: return "music.note.list"
        }
    }
}

/// Modèle unifié représentant un élément musical Spotify sélectionné pour une alarme.
public struct SpotifyTrackItem: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let artistName: String
    public let albumName: String?
    public let imageUrl: String?
    public let uri: String
    public let type: SpotifyItemType
    
    public init(
        id: String,
        name: String,
        artistName: String,
        albumName: String? = nil,
        imageUrl: String? = nil,
        uri: String,
        type: SpotifyItemType
    ) {
        self.id = id
        self.name = name
        self.artistName = artistName
        self.albumName = albumName
        self.imageUrl = imageUrl
        self.uri = uri
        self.type = type
    }
    
    /// Génère un URL direct pour ouvrir Spotify
    public var spotifyDeepLinkURL: URL? {
        // Schéma spotify direct ex: spotify:track:xxxx
        return URL(string: uri)
    }
    
    /// Génère un lien Web / Universal Link
    public var webURL: URL? {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: "https://open.spotify.com/\(type.rawValue)/\(cleanId)")
    }
}

// MARK: - Modèles DTO Spotify API

/// Image Spotify (plusieurs résolutions disponibles dans l'API)
public struct SpotifyImage: Codable, Equatable {
    public let url: String
    public let height: Int?
    public let width: Int?
}

/// Profil utilisateur Spotify
public struct SpotifyUserProfile: Codable, Identifiable {
    public let id: String
    public let displayName: String?
    public let email: String?
    public let product: String? // "premium", "free", etc.
    public let images: [SpotifyImage]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case product
        case images
    }
    
    public var isPremium: Bool {
        return product?.lowercased() == "premium"
    }
    
    public var avatarUrl: String? {
        return images?.first?.url
    }
}

/// Réponse du point de terminaison de jetons OAuth (Token Endpoint)
public struct SpotifyTokenResponse: Codable {
    public let accessToken: String
    public let tokenType: String
    public let scope: String?
    public let expiresIn: Int
    public let refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

/// Appareil Spotify Connect
public struct SpotifyDevice: Codable, Identifiable {
    public let id: String?
    public let isActive: Bool
    public let isPrivateSession: Bool
    public let isRestricted: Bool
    public let name: String
    public let type: String
    public let volumePercent: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case isActive = "is_active"
        case isPrivateSession = "is_private_session"
        case isRestricted = "is_restricted"
        case name
        case type
        case volumePercent = "volume_percent"
    }
}

public struct SpotifyDevicesResponse: Codable {
    public let devices: [SpotifyDevice]
}

// MARK: - Structures de Recherche Spotify

public struct SpotifySearchResponse: Codable {
    public let tracks: SpotifyTracksPaging?
    public let albums: SpotifyAlbumsPaging?
    public let playlists: SpotifyPlaylistsPaging?
}

public struct SpotifyTracksPaging: Codable {
    public let items: [SpotifyRawTrack]
}

public struct SpotifyAlbumsPaging: Codable {
    public let items: [SpotifyRawAlbum]
}

public struct SpotifyPlaylistsPaging: Codable {
    public let items: [SpotifyRawPlaylist]
}

public struct SpotifyRawTrack: Codable {
    public let id: String
    public let name: String
    public let uri: String
    public let artists: [SpotifyRawArtist]?
    public let album: SpotifyRawAlbumBrief?
}

public struct SpotifyRawArtist: Codable {
    public let id: String?
    public let name: String
}

public struct SpotifyRawAlbumBrief: Codable {
    public let id: String?
    public let name: String?
    public let images: [SpotifyImage]?
}

public struct SpotifyRawAlbum: Codable {
    public let id: String
    public let name: String
    public let uri: String
    public let artists: [SpotifyRawArtist]?
    public let images: [SpotifyImage]?
}

public struct SpotifyRawPlaylist: Codable {
    public let id: String
    public let name: String
    public let uri: String
    public let description: String?
    public let images: [SpotifyImage]?
    public let owner: SpotifyRawOwner?
}

public struct SpotifyRawOwner: Codable {
    public let displayName: String?
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

public struct SpotifyUserPlaylistsResponse: Codable {
    public let items: [SpotifyRawPlaylist]
}
