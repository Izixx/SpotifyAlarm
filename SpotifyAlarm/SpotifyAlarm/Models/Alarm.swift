import Foundation

/// Modèle principal représentant une alarme configurée par l'utilisateur.
public struct Alarm: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var time: Date
    public var repeatDays: Set<RepeatDay>
    public var spotifyItem: SpotifyTrackItem?
    public var customAudioFileName: String?
    public var customAudioTitle: String?
    public var vibrateOnBeat: Bool
    public var volume: Float
    public var isEnabled: Bool
    public var isSmartAlarmEnabled: Bool
    public var smartAlarmWindowMinutes: Int
    
    public init(
        id: UUID = UUID(),
        title: String = "Alarme",
        time: Date = Date(),
        repeatDays: Set<RepeatDay> = [],
        spotifyItem: SpotifyTrackItem? = nil,
        customAudioFileName: String? = nil,
        customAudioTitle: String? = nil,
        vibrateOnBeat: Bool = true,
        volume: Float = 0.8,
        isEnabled: Bool = true,
        isSmartAlarmEnabled: Bool = false,
        smartAlarmWindowMinutes: Int = 30
    ) {
        self.id = id
        self.title = title
        self.time = time
        self.repeatDays = repeatDays
        self.spotifyItem = spotifyItem
        self.customAudioFileName = customAudioFileName
        self.customAudioTitle = customAudioTitle
        self.vibrateOnBeat = vibrateOnBeat
        self.volume = max(0.0, min(1.0, volume))
        self.isEnabled = isEnabled
        self.isSmartAlarmEnabled = isSmartAlarmEnabled
        self.smartAlarmWindowMinutes = smartAlarmWindowMinutes
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, time, repeatDays, spotifyItem, volume, isEnabled
        case customAudioFileName, customAudioTitle, vibrateOnBeat
        case isSmartAlarmEnabled, smartAlarmWindowMinutes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.time = try container.decode(Date.self, forKey: .time)
        self.repeatDays = try container.decode(Set<RepeatDay>.self, forKey: .repeatDays)
        self.spotifyItem = try container.decodeIfPresent(SpotifyTrackItem.self, forKey: .spotifyItem)
        self.volume = try container.decode(Float.self, forKey: .volume)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.customAudioFileName = try container.decodeIfPresent(String.self, forKey: .customAudioFileName)
        self.customAudioTitle = try container.decodeIfPresent(String.self, forKey: .customAudioTitle)
        self.vibrateOnBeat = try container.decodeIfPresent(Bool.self, forKey: .vibrateOnBeat) ?? true
        self.isSmartAlarmEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSmartAlarmEnabled) ?? false
        self.smartAlarmWindowMinutes = try container.decodeIfPresent(Int.self, forKey: .smartAlarmWindowMinutes) ?? 30
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
        } else if let title = customAudioTitle, !title.isEmpty {
            return "Fichier audio : \(title)"
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
