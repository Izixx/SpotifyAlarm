import Foundation

/// Modèle principal représentant une alarme configurée par l'utilisateur.
public struct Alarm: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var time: Date
    public var repeatDays: Set<RepeatDay>
    public var spotifyItem: SpotifyTrackItem?
    public var volume: Float
    public var isEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        title: String = "Alarme",
        time: Date = Date(),
        repeatDays: Set<RepeatDay> = [],
        spotifyItem: SpotifyTrackItem? = nil,
        volume: Float = 0.8,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.time = time
        self.repeatDays = repeatDays
        self.spotifyItem = spotifyItem
        self.volume = max(0.0, min(1.0, volume))
        self.isEnabled = isEnabled
    }
    
    /// Heure formatée (ex: "07:00")
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
    
    /// Description des répétitions
    public var repeatDescription: String {
        return RepeatDay.summary(for: repeatDays)
    }
    
    /// Description de la musique sélectionnée
    public var musicDescription: String {
        if let item = spotifyItem {
            return "\(item.name) • \(item.artistName)"
        }
        return "Sonnerie standard (Carillon)"
    }
    
    /// Heures et minutes sous forme de tuple pour la planification
    public var timeComponents: (hour: Int, minute: Int) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        return (hour, minute)
    }
    
    /// Calcule la prochaine date de déclenchement de cette alarme.
    public func nextTriggerDate(from currentDate: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let (alarmHour, alarmMinute) = timeComponents
        
        // Si aucun jour répété, calculer la prochaine occurrence aujourd'hui ou demain
        if repeatDays.isEmpty {
            var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
            components.hour = alarmHour
            components.minute = alarmMinute
            components.second = 0
            
            guard let candidate = calendar.date(from: components) else { return nil }
            if candidate > currentDate {
                return candidate
            } else {
                // Demain à la même heure
                return calendar.date(byAdding: .day, value: 1, to: candidate)
            }
        }
        
        // Pour les alarmes avec répétition de jours
        var nextDates: [Date] = []
        for day in repeatDays {
            var matchingComponents = DateComponents()
            matchingComponents.hour = alarmHour
            matchingComponents.minute = alarmMinute
            matchingComponents.second = 0
            matchingComponents.weekday = day.rawValue
            
            if let next = calendar.nextDate(
                after: currentDate,
                matching: matchingComponents,
                matchingPolicy: .nextTime
            ) {
                nextDates.append(next)
            }
        }
        
        return nextDates.min()
    }
}
