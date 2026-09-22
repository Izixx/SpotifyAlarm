import Foundation

/// Les 4 phases fondamentales du sommeil
public enum SleepStage: String, Codable, CaseIterable, Equatable {
    case awake = "awake"        // Éveillé (micro-réveils)
    case rem = "rem"            // Paradoxal (rêves, régénération cognitive)
    case light = "light"        // Léger (transition, repos musculaire)
    case deep = "deep"          // Profond (récupération physique, ondes lentes)
    
    public var displayName: String {
        switch self {
        case .awake: return "Éveillé"
        case .rem: return "Paradoxal (REM)"
        case .light: return "Léger"
        case .deep: return "Profond"
        }
    }
    
    public var shortName: String {
        switch self {
        case .awake: return "Éveil"
        case .rem: return "REM"
        case .light: return "Léger"
        case .deep: return "Profond"
        }
    }
    
    public var systemIcon: String {
        switch self {
        case .awake: return "eye.fill"
        case .rem: return "sparkles"
        case .light: return "cloud.fill"
        case .deep: return "moon.stars.fill"
        }
    }
    
    public var colorHex: String {
        switch self {
        case .awake: return "#F59E0B" // Ambre
        case .rem: return "#8B5CF6"   // Violet
        case .light: return "#38BDF8" // Bleu azur
        case .deep: return "#1D4ED8"  // Bleu royal profond
        }
    }
    
    /// Ordre vertical pour le tracé de l'hypnogramme (3 = en haut, 0 = en bas)
    public var chartLevel: Double {
        switch self {
        case .awake: return 3.0
        case .rem: return 2.0
        case .light: return 1.0
        case .deep: return 0.0
        }
    }
}

/// Époque d'enregistrement de sommeil (mesure toutes les 1 à 5 minutes)
public struct SleepStageEpoch: Identifiable, Codable, Equatable {
    public var id: UUID
    public var timestamp: Date
    public var stage: SleepStage
    public var soundLevelDB: Double // Niveau sonore estimé (ex: 25 - 65 dB)
    public var motionIntensity: Double // Intensité de mouvement normalisée (0.0 à 1.0)
    
    public init(
        id: UUID = UUID(),
        timestamp: Date,
        stage: SleepStage,
        soundLevelDB: Double = 30.0,
        motionIntensity: Double = 0.0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.stage = stage
        self.soundLevelDB = soundLevelDB
        self.motionIntensity = motionIntensity
    }
}

/// Modèle complet représentant une session de sommeil enregistrée avec hypnogramme
public struct SleepSession: Identifiable, Codable, Equatable {
    public var id: UUID
    public var startDate: Date // Heure de coucher
    public var endDate: Date   // Heure de réveil
    public var targetDurationHours: Double // Objectif en heures (ex: 8.0)
    public var qualityRating: Int // Note de qualité de 1 à 5 étoiles
    public var notes: String?
    
    // Données d'analyse avancée (Sleep Tracker)
    public var stages: [SleepStageEpoch]
    public var snoreDurationMinutes: Int
    public var snoreEpisodesCount: Int
    public var averageSoundDB: Double
    public var calculatedSleepScore: Int // Score de 0 à 100
    
    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        targetDurationHours: Double = 8.0,
        qualityRating: Int = 4,
        notes: String? = nil,
        stages: [SleepStageEpoch] = [],
        snoreDurationMinutes: Int = 0,
        snoreEpisodesCount: Int = 0,
        averageSoundDB: Double = 32.0,
        calculatedSleepScore: Int = 0
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.targetDurationHours = targetDurationHours
        self.qualityRating = max(1, min(5, qualityRating))
        self.notes = notes
        self.stages = stages
        self.snoreDurationMinutes = snoreDurationMinutes
        self.snoreEpisodesCount = snoreEpisodesCount
        self.averageSoundDB = averageSoundDB
        self.calculatedSleepScore = calculatedSleepScore
    }
    
    enum CodingKeys: String, CodingKey {
        case id, startDate, endDate, targetDurationHours, qualityRating, notes
        case stages, snoreDurationMinutes, snoreEpisodesCount, averageSoundDB, calculatedSleepScore
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decode(Date.self, forKey: .endDate)
        self.targetDurationHours = try container.decodeIfPresent(Double.self, forKey: .targetDurationHours) ?? 8.0
        self.qualityRating = try container.decodeIfPresent(Int.self, forKey: .qualityRating) ?? 4
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.stages = try container.decodeIfPresent([SleepStageEpoch].self, forKey: .stages) ?? []
        self.snoreDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .snoreDurationMinutes) ?? 0
        self.snoreEpisodesCount = try container.decodeIfPresent(Int.self, forKey: .snoreEpisodesCount) ?? 0
        self.averageSoundDB = try container.decodeIfPresent(Double.self, forKey: .averageSoundDB) ?? 32.0
        self.calculatedSleepScore = try container.decodeIfPresent(Int.self, forKey: .calculatedSleepScore) ?? 0
    }
    
    // MARK: - Propriétés Temporelles
    
    public var durationSeconds: TimeInterval {
        return max(0, endDate.timeIntervalSince(startDate))
    }
    
    public var durationHours: Double {
        return durationSeconds / 3600.0
    }
    
    public var formattedDuration: String {
        let totalMinutes = Int(durationSeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(String(format: "%02d", minutes))m"
    }
    
    public var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }
    
    public var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: endDate)
    }
    
    public var formattedNightSummary: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM"
        return "Nuit du \(formatter.string(from: startDate))"
    }
    
    // MARK: - Analyse des Phases & Pourcentages
    
    public var deepSleepPercentage: Double {
        guard !stages.isEmpty else { return 25.0 }
        let count = stages.filter { $0.stage == .deep }.count
        return (Double(count) / Double(stages.count)) * 100.0
    }
    
    public var lightSleepPercentage: Double {
        guard !stages.isEmpty else { return 50.0 }
        let count = stages.filter { $0.stage == .light }.count
        return (Double(count) / Double(stages.count)) * 100.0
    }
    
    public var remSleepPercentage: Double {
        guard !stages.isEmpty else { return 18.0 }
        let count = stages.filter { $0.stage == .rem }.count
        return (Double(count) / Double(stages.count)) * 100.0
    }
    
    public var awakePercentage: Double {
        guard !stages.isEmpty else { return 7.0 }
        let count = stages.filter { $0.stage == .awake }.count
        return (Double(count) / Double(stages.count)) * 100.0
    }
    
    public var deepSleepDurationFormatted: String {
        let seconds = (deepSleepPercentage / 100.0) * durationSeconds
        let m = Int(seconds / 60)
        return "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }
    
    public var lightSleepDurationFormatted: String {
        let seconds = (lightSleepPercentage / 100.0) * durationSeconds
        let m = Int(seconds / 60)
        return "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }
    
    public var remSleepDurationFormatted: String {
        let seconds = (remSleepPercentage / 100.0) * durationSeconds
        let m = Int(seconds / 60)
        return "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }
    
    public var awakeDurationFormatted: String {
        let seconds = (awakePercentage / 100.0) * durationSeconds
        let m = Int(seconds / 60)
        return "\(m) min"
    }
    
    // MARK: - Score de Sommeil
    
    public var displaySleepScore: Int {
        if calculatedSleepScore > 0 {
            return calculatedSleepScore
        }
        // Fallback calculé à partir de la note et de la durée
        let durationRatio = min(1.0, durationHours / max(1.0, targetDurationHours))
        let scoreFromStars = Double(qualityRating) * 20.0
        return Int((scoreFromStars * 0.6) + (durationRatio * 40.0))
    }
    
    public var sleepScoreVerdict: String {
        switch displaySleepScore {
        case 90...100: return "Sommeil Exceptionnel"
        case 80..<90:  return "Sommeil Réparateur"
        case 70..<80:  return "Bon Sommeil"
        case 60..<70:  return "Sommeil Moyen"
        default:       return "Sommeil Agité"
        }
    }
    
    public var formattedSnoreDuration: String {
        if snoreDurationMinutes == 0 {
            return "Aucun ronflement"
        }
        return "\(snoreDurationMinutes) min"
    }
    
    public var soundEnvironmentDescription: String {
        if averageSoundDB < 35 {
            return "Chambre très calme (\(Int(averageSoundDB)) dB)"
        } else if averageSoundDB < 48 {
            return "Ambiance modérée (\(Int(averageSoundDB)) dB)"
        } else {
            return "Environnement bruyant (\(Int(averageSoundDB)) dB)"
        }
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
    public let sleepDebtHours: Double
    public let regularityScore: Int
    public let totalNightsTracked: Int
    public let weeklyBars: [DailySleepBarData]
    public let averageSleepScore: Int
    public let averageDeepSleepPercentage: Double
    public let totalSnoreMinutes: Int
    
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
            weeklyBars: [],
            averageSleepScore: 0,
            averageDeepSleepPercentage: 0,
            totalSnoreMinutes: 0
        )
    }
}
