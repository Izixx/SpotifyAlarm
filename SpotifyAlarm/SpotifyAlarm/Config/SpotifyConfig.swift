import Foundation

/// Configuration pour l'intégration de l'API Spotify avec Authorization Code + PKCE.
///
/// Pour obtenir votre Client ID :
/// 1. Rendez-vous sur https://developer.spotify.com/dashboard
/// 2. Créez une application "Spotify Alarm"
/// 3. Dans "Edit Settings", ajoutez la Redirect URI : `spotifyalarm://callback`
/// 4. Copiez votre `Client ID` ci-dessous.
///
/// NOTE DE SÉCURITÉ :
/// Aucun `Client Secret` n'est requis ni utilisé ici grâce à l'implémentation PKCE (RFC 7636).
public struct SpotifyConfig {
    
    /// Votre Spotify Client ID issu du Developer Dashboard.
    /// Remplacez cette valeur par votre véritable Client ID Spotify.
    public static let clientID = "23e0e6a224c4446d8720055b091324f4"
    
    /// Schéma de redirection configuré dans Info.plist et le dashboard Spotify.
    public static let redirectURI = "spotifyalarm://callback"
    
    /// Permissions demandées à l'utilisateur lors de la connexion OAuth.
    public static let scopes = [
        "user-read-private",
        "user-read-email",
        "user-read-playback-state",
        "user-modify-playback-state",
        "playlist-read-private",
        "playlist-read-collaborative"
    ].joined(separator: " ")
    
    /// Indique si l'utilisateur a configuré un vrai Client ID.
    public static var isConfigured: Bool {
        let trimmed = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "YOUR_SPOTIFY_CLIENT_ID"
    }
}
