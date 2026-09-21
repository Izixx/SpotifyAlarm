import Foundation
import Combine

/// Service de gestion et persistance locale des alarmes
@MainActor
public final class AlarmService: ObservableObject {
    
    public static let shared = AlarmService()
    
    @Published public var alarms: [Alarm] = []
    
    private let notificationService = NotificationService.shared
    private let fileName = "spotify_alarms.json"
    
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }
    
    private init() {
        loadAlarms()
    }
    
    // MARK: - Chargement & Persistance
    
    public func loadAlarms() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Création des alarmes par défaut pour démarrer (exemples du cahier des charges)
            self.alarms = createDefaultSampleAlarms()
            saveToDisk()
            rescheduleAllEnabledAlarms()
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode([Alarm].self, from: data)
            self.alarms = loaded
            rescheduleAllEnabledAlarms()
        } catch {
            print("Erreur de chargement des alarmes: \(error.localizedDescription)")
            self.alarms = []
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(alarms)
            try data.write(to: fileURL, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Erreur de sauvegarde des alarmes: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CRUD
    
    /// Ajoute ou met à jour une alarme
    public func saveAlarm(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
        
        // Tri chronologique des alarmes
        alarms.sort { a1, a2 in
            let (h1, m1) = a1.timeComponents
            let (h2, m2) = a2.timeComponents
            if h1 != h2 { return h1 < h2 }
            return m1 < m2
        }
        
        saveToDisk()
        notificationService.scheduleAlarmNotification(for: alarm)
    }
    
    /// Bascule l'état ON/OFF d'une alarme
    public func toggleAlarm(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index].isEnabled.toggle()
        let updatedAlarm = alarms[index]
        saveToDisk()
        
        if updatedAlarm.isEnabled {
            notificationService.scheduleAlarmNotification(for: updatedAlarm)
        } else {
            notificationService.cancelAlarmNotification(for: updatedAlarm)
        }
    }
    
    /// Supprime une alarme
    public func deleteAlarm(id: UUID) {
        if let alarm = alarms.first(where: { $0.id == id }) {
            notificationService.cancelAlarmNotification(for: alarm)
        }
        alarms.removeAll { $0.id == id }
        saveToDisk()
    }
    
    /// Supprime des alarmes via un IndexSet (glissement dans une List SwiftUI)
    public func deleteAlarms(at offsets: IndexSet) {
        for index in offsets {
            let alarm = alarms[index]
            notificationService.cancelAlarmNotification(for: alarm)
        }
        alarms.remove(atOffsets: offsets)
        saveToDisk()
    }
    
    /// Re-planifie toutes les alarmes actives auprès d'iOS
    public func rescheduleAllEnabledAlarms() {
        for alarm in alarms where alarm.isEnabled {
            notificationService.scheduleAlarmNotification(for: alarm)
        }
    }
    
    // MARK: - Exemples par défaut
    
    private func createDefaultSampleAlarms() -> [Alarm] {
        let calendar = Calendar.current
        var comps1 = calendar.dateComponents([.year, .month, .day], from: Date())
        comps1.hour = 7
        comps1.minute = 0
        let time1 = calendar.date(from: comps1) ?? Date()
        
        var comps2 = calendar.dateComponents([.year, .month, .day], from: Date())
        comps2.hour = 8
        comps2.minute = 30
        let time2 = calendar.date(from: comps2) ?? Date()
        
        let sampleTrack = SpotifyTrackItem(
            id: "sample_track_1",
            name: "Morning Sunlight",
            artistName: "Acoustic Morning",
            albumName: "Wake Up Happy",
            imageUrl: nil,
            uri: "spotify:track:4cOdK2wGLETKBW3PvgPWqT",
            type: .track
        )
        
        return [
            Alarm(
                title: "Réveil Semaine",
                time: time1,
                repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
                spotifyItem: sampleTrack,
                volume: 0.8,
                isEnabled: true
            ),
            Alarm(
                title: "Grasse matinée",
                time: time2,
                repeatDays: [.saturday, .sunday],
                spotifyItem: nil,
                volume: 0.6,
                isEnabled: false
            )
        ]
    }
}
