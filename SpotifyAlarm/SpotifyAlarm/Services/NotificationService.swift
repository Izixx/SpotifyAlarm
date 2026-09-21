import Foundation
import UserNotifications

/// Service de gestion des notifications locales d'alarme avec UserNotifications.
public final class NotificationService {
    
    public static let shared = NotificationService()
    
    public static let categoryIdentifier = "SPOTIFY_ALARM_CATEGORY"
    public static let actionOpenSpotify = "OPEN_SPOTIFY_ACTION"
    public static let actionStopAlarm = "STOP_ALARM_ACTION"
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {
        registerCategories()
    }
    
    // MARK: - Enregistrement des Catégories & Actions
    
    public func registerCategories() {
        let openAction = UNNotificationAction(
            identifier: Self.actionOpenSpotify,
            title: "🎵 Lancer Spotify",
            options: [.foreground]
        )
        
        let stopAction = UNNotificationAction(
            identifier: Self.actionStopAlarm,
            title: "Arrêter l'alarme",
            options: [.destructive]
        )
        
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [openAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        center.setNotificationCategories([category])
    }
    
    // MARK: - Demande d'Autorisation
    
    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await center.requestAuthorization(options: options)
            return granted
        } catch {
            print("Erreur de demande d'autorisation de notifications: \(error)")
            return false
        }
    }
    
    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Planification des Alarmes
    
    public func scheduleAlarmNotification(for alarm: Alarm) {
        // Annuler les notifications existantes pour cette alarme
        cancelAlarmNotification(for: alarm)
        
        guard alarm.isEnabled else { return }
        
        let (hour, minute) = alarm.timeComponents
        
        if alarm.repeatDays.isEmpty {
            // Alarme ponctuelle
            guard let nextDate = alarm.nextTriggerDate() else { return }
            let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            
            let content = createNotificationContent(for: alarm)
            let request = UNNotificationRequest(
                identifier: alarm.id.uuidString,
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Erreur lors de la programmation de la notification: \(error)")
                }
            }
        } else {
            // Alarme récurrente pour chaque jour sélectionné
            for day in alarm.repeatDays {
                var triggerComponents = DateComponents()
                triggerComponents.hour = hour
                triggerComponents.minute = minute
                triggerComponents.second = 0
                triggerComponents.weekday = day.rawValue
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
                let content = createNotificationContent(for: alarm)
                let identifier = "\(alarm.id.uuidString)_\(day.rawValue)"
                
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )
                
                center.add(request) { error in
                    if let error = error {
                        print("Erreur lors de la programmation du jour \(day.shortName): \(error)")
                    }
                }
            }
        }
    }
    
    public func cancelAlarmNotification(for alarm: Alarm) {
        // Récupérer les identifiants en attente correspondant à cet alarmId
        center.getPendingNotificationRequests { [weak self] requests in
            let prefix = alarm.id.uuidString
            let idsToRemove = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(prefix) }
            
            if !idsToRemove.isEmpty {
                self?.center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            }
        }
    }
    
    // MARK: - Test Immédiat d'Alarme
    
    public func scheduleTestNotification(
        in seconds: TimeInterval = 3.0,
        spotifyItem: SpotifyTrackItem? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let content = UNMutableNotificationContent()
        content.title = "⏰ Test d'alarme Spotify"
        if let item = spotifyItem {
            content.body = "🎵 \(item.name) — \(item.artistName)\nTapez pour lancer la musique !"
            content.userInfo = ["spotifyUri": item.uri, "isTest": true]
        } else {
            content.body = "🔔 Votre alarme fonctionne parfaitement !\nTapez pour ouvrir Spotify Alarm."
            content.userInfo = ["isTest": true]
        }
        
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_sound.wav"))
        content.categoryIdentifier = Self.categoryIdentifier
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1.0, seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "TEST_ALARM_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Erreur test notification: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func createNotificationContent(for alarm: Alarm) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.title.isEmpty ? "⏰ Réveil Spotify" : alarm.title
        
        if let item = alarm.spotifyItem {
            content.body = "🎵 \(item.name) — \(item.artistName)"
            content.userInfo = [
                "alarmId": alarm.id.uuidString,
                "spotifyUri": item.uri,
                "volume": alarm.volume
            ]
        } else {
            content.body = "⏰ Il est l'heure de vous réveiller !"
            content.userInfo = [
                "alarmId": alarm.id.uuidString,
                "volume": alarm.volume
            ]
        }
        
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_sound.wav"))
        content.categoryIdentifier = Self.categoryIdentifier
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        
        return content
    }
}
