import UIKit
import UserNotifications

/// Délégué de l'application gérant les réceptions de notifications et les actions d'alarme
public final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Définir le délégué UNUserNotificationCenter
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // Enregistrer les catégories d'actions d'alarme
        NotificationService.shared.registerCategories()
        
        // Re-synchroniser les alarmes actives
        Task { @MainActor in
            AlarmService.shared.rescheduleAllEnabledAlarms()
        }
        
        return true
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Présente la bannière et le son même lorsque l'application est au premier plan
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    /// Gère l'interaction de l'utilisateur avec la notification (clic sur bannière ou action)
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // Si l'utilisateur clique sur "Arrêter"
        if actionIdentifier == NotificationService.actionStopAlarm {
            AudioPlayerService.shared.stopAlarmSound()
            completionHandler()
            return
        }
        
        // Si l'utilisateur clique sur "Lancer Spotify" ou touche directement la notification
        if actionIdentifier == NotificationService.actionOpenSpotify ||
           actionIdentifier == UNNotificationDefaultActionIdentifier {
            
            if let spotifyUri = userInfo["spotifyUri"] as? String, !spotifyUri.isEmpty {
                // Ouvrir Spotify directement via le deep link
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    SpotifyAPIService.shared.openSpotifyApp(uri: spotifyUri)
                }
            } else {
                // Pas de morceau Spotify : jouer la sonnerie de secours locale
                let volume = (userInfo["volume"] as? Float) ?? 0.8
                AudioPlayerService.shared.playAlarmSound(targetVolume: volume)
            }
        }
        
        completionHandler()
    }
}
