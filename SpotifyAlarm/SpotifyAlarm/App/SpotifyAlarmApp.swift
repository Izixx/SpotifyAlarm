import SwiftUI

@main
public struct SpotifyAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authService = SpotifyAuthService.shared
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            AlarmListView()
                .environmentObject(authService)
                .onOpenURL { url in
                    // Gestion de l'URL de retour personnalisée si nécessaire
                    if url.scheme == "spotifyalarm" {
                        print("URL Callback reçue: \(url)")
                    }
                }
        }
    }
}
