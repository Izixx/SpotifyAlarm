import Foundation

/// Modèle représentant une session de sommeil enregistrée
public struct SleepSession: Identifiable, Codable, Equatable {
    public var id: UUID
    public var startDate: Date // Heure de coucher
    public var endDate: Date   // Heure de réveil
    public var targetDurationHours: Double // Objectif en heures (ex: 8.0)
    public var qualityRating: Int // Note de qualité de 1 à 5 étoiles
    public var notes: String?
    
    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        targetDurationHours: Double = 8.0,
        qualityRating: Int = 4,
        notes: String? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.targetDurationHours = targetDurationHours
        self.qualityRating = max(1, min(5, qualityRating))
        self.notes = notes
    }
    
    /// Durée de sommeil en secondes
    public var durationSeconds: TimeInterval {
        return max(0, endDate.timeIntervalSince(startDate))
    }
    
    /// Durée de sommeil en heures décimales
    public var durationHours: Double {
        return durationSeconds / 3600.0
    }
    
    /// Durée formatée (ex: "7h 45m")
    public var formattedDuration: String {
        let totalMinutes = Int(durationSeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(String(format: "%02d", minutes))m"
    }
    
    /// Heure de coucher formatée (ex: "23:15")
    public var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }
    
    /// Heure de réveil formatée (ex: "07:30")
    public var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: endDate)
    }
    
    /// Résumé du jour formaté (ex: "Nuit du lundi 21 septembre")
    public var formattedNightSummary: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM"
        return "Nuit du \(formatter.string(from: startDate))"
    }
}

/// Donnée d'une nuit pour le graphique hebdomadaire
public struct DailySleepBarData: Identifiable, Equatable {
    public var id: String { dayLabel }
    public let dayLabel: String // "Lun", "Mar", etc.
    public let durationHours: Double
    public let date: Date
    public let isTargetReached: Bool
}

/// Suggestion de réveil basée sur les cycles de 90 minutes
public struct SleepCycleSuggestion: Identifiable, Equatable {
    public var id: Int { cyclesCount }
    public let cyclesCount: Int
    public let wakeUpTime: Date
    public let formattedTime: String
    public let totalSleepFormatted: String
    public let isRecommended: Bool
}

/// Statistiques et moyennes consolidées du sommeil
public struct SleepStats: Equatable {
    public let averageDurationSeconds: TimeInterval
    public let averageDurationHours: Double
    public let formattedAverageDuration: String
    public let averageBedtimeString: String
    public let averageWakeTimeString: String
    public let sleepDebtHours: Double // Positif = manque de sommeil, négatif = surplus
    public let regularityScore: Int // Score de 0 à 100%
    public let totalNightsTracked: Int
    public let weeklyBars: [DailySleepBarData]
    
    public static var empty: SleepStats {
        return SleepStats(
            averageDurationSeconds: 0,
            averageDurationHours: 0,
            formattedAverageDuration: "0h 00m",
            averageBedtimeString: "--:--",
            averageWakeTimeString: "--:--",
            sleepDebtHours: 0,
            regularityScore: 0,
            totalNightsTracked: 0,
            weeklyBars: []
        )
    }
}
