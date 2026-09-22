import SwiftUI

@main
public struct SpotifyAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authService = SpotifyAuthService.shared
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(authService)
                .onOpenURL { url in
                    if url.scheme == "spotifyalarm" {
                        Task {
                            await authService.handleRedirectURL(url)
                        }
                    }
                }
        }
    }
}
