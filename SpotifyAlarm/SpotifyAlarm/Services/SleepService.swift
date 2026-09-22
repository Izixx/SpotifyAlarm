import Foundation
import Combine

/// Service de gestion, enregistrement et analyse du sommeil
@MainActor
public final class SleepService: ObservableObject {
    
    public static let shared = SleepService()
    
    @Published public var sessions: [SleepSession] = []
    @Published public var activeSessionStart: Date? = nil
    @Published public var targetSleepHours: Double = 8.0
    @Published public var stats: SleepStats = .empty
    
    private let fileName = "sleep_sessions.json"
    private let activeSessionKey = "active_sleep_session_start"
    private let targetHoursKey = "user_target_sleep_hours"
    
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }
    
    private init() {
        loadSettings()
        loadSessions()
        checkActiveSession()
        refreshStats()
    }
    
    // MARK: - Persistance des Sessions
    
    public func loadSessions() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Sessions initiales d'exemple pour un affichage immédiat élégant
            self.sessions = createSampleSessions()
            saveToDisk()
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode([SleepSession].self, from: data)
            self.sessions = loaded.sorted(by: { $0.startDate > $1.startDate })
        } catch {
            print("Erreur de chargement du sommeil: \(error.localizedDescription)")
            self.sessions = createSampleSessions()
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: fileURL, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Erreur de sauvegarde du sommeil: \(error.localizedDescription)")
        }
    }
    
    private func loadSettings() {
        let savedTarget = UserDefaults.standard.double(forKey: targetHoursKey)
        if savedTarget > 0 {
            self.targetSleepHours = savedTarget
        }
    }
    
    public func updateTargetSleepHours(_ hours: Double) {
        self.targetSleepHours = max(4.0, min(12.0, hours))
        UserDefaults.standard.set(self.targetSleepHours, forKey: targetHoursKey)
        refreshStats()
    }
    
    private func checkActiveSession() {
        if let timestamp = UserDefaults.standard.object(forKey: activeSessionKey) as? Date {
            // Si la session date de moins de 24h, on la conserve
            if Date().timeIntervalSince(timestamp) < 24 * 3600 {
                self.activeSessionStart = timestamp
            } else {
                UserDefaults.standard.removeObject(forKey: activeSessionKey)
                self.activeSessionStart = nil
            }
        }
    }
    
    // MARK: - Démarrage et Fin de Session en Direct
    
    /// Démarre l'enregistrement du sommeil (ex: au coucher ou en entrant dans le Mode Chevet)
    public func startSleepSession(at date: Date = Date()) {
        guard activeSessionStart == nil else { return }
        self.activeSessionStart = date
        UserDefaults.standard.set(date, forKey: activeSessionKey)
    }
    
    /// Clôture la session en cours et enregistre la nuit de sommeil
    @discardableResult
    public func endSleepSession(at date: Date = Date(), quality: Int = 4, notes: String? = nil) -> SleepSession? {
        guard let start = activeSessionStart else { return nil }
        
        let session = SleepSession(
            startDate: start,
            endDate: date,
            targetDurationHours: targetSleepHours,
            qualityRating: quality,
            notes: notes
        )
        
        // On n'enregistre que si la session a duré au moins 10 minutes pour éviter les faux déclenchements
        if session.durationSeconds >= 600 {
            sessions.insert(session, at: 0)
            sessions.sort(by: { $0.startDate > $1.startDate })
            saveToDisk()
        }
        
        self.activeSessionStart = nil
        UserDefaults.standard.removeObject(forKey: activeSessionKey)
        refreshStats()
        return session
    }
    
    /// Annule la session de sommeil active sans l'enregistrer
    public func cancelActiveSession() {
        self.activeSessionStart = nil
        UserDefaults.standard.removeObject(forKey: activeSessionKey)
    }
    
    // MARK: - Gestion Manuelle
    
    /// Ajoute manuellement une nuit passée
    public func addManualSession(startDate: Date, endDate: Date, quality: Int = 4, notes: String? = nil) {
        guard endDate > startDate else { return }
        let session = SleepSession(
            startDate: startDate,
            endDate: endDate,
            targetDurationHours: targetSleepHours,
            qualityRating: quality,
            notes: notes
        )
        sessions.append(session)
        sessions.sort(by: { $0.startDate > $1.startDate })
        saveToDisk()
        refreshStats()
    }
    
    /// Supprime une session enregistrée
    public func deleteSession(id: UUID) {
        sessions.removeAll(where: { $0.id == id })
        saveToDisk()
        refreshStats()
    }
    
    // MARK: - Calcul des Moyennes et Données Analytiques
    
    public func refreshStats() {
        guard !sessions.isEmpty else {
            self.stats = .empty
            return
        }
        
        // 1. Durée moyenne (sur les 7 dernières sessions)
        let recent = Array(sessions.prefix(7))
        let totalDuration = recent.reduce(0.0) { $0 + $1.durationSeconds }
        let avgDurationSeconds = totalDuration / Double(recent.count)
        let avgDurationHours = avgDurationSeconds / 3600.0
        
        let totalMinutes = Int(avgDurationSeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let formattedAvg = "\(hours)h \(String(format: "%02d", minutes))m"
        
        // 2. Heure moyenne de coucher
        let avgBedtime = calculateAverageTimeOfDay(dates: recent.map { $0.startDate }, anchorMidnight: true)
        
        // 3. Heure moyenne de réveil
        let avgWakeTime = calculateAverageTimeOfDay(dates: recent.map { $0.endDate }, anchorMidnight: false)
        
        // 4. Dette de sommeil (par rapport à l'objectif)
        let expectedTotalHours = targetSleepHours * Double(recent.count)
        let actualTotalHours = totalDuration / 3600.0
        let debt = expectedTotalHours - actualTotalHours
        
        // 5. Score de régularité (0 à 100%)
        let regularity = calculateRegularityScore(sessions: recent)
        
        // 6. Barres hebdomadaires (7 derniers jours)
        let weeklyBars = buildWeeklyBars()
        
        self.stats = SleepStats(
            averageDurationSeconds: avgDurationSeconds,
            averageDurationHours: avgDurationHours,
            formattedAverageDuration: formattedAvg,
            averageBedtimeString: avgBedtime,
            averageWakeTimeString: avgWakeTime,
            sleepDebtHours: debt,
            regularityScore: regularity,
            totalNightsTracked: sessions.count,
            weeklyBars: weeklyBars
        )
    }
    
    private func calculateAverageTimeOfDay(dates: [Date], anchorMidnight: Bool) -> String {
        guard !dates.isEmpty else { return "--:--" }
        let calendar = Calendar.current
        
        var totalMinutes = 0
        for date in dates {
            let h = calendar.component(.hour, from: date)
            let m = calendar.component(.minute, from: date)
            var minutesFromMidnight = h * 60 + m
            if anchorMidnight && h < 12 {
                // Pour les couchers après minuit (ex: 01:00 = 25:00)
                minutesFromMidnight += 24 * 60
            }
            totalMinutes += minutesFromMidnight
        }
        
        var avgMinutes = totalMinutes / dates.count
        if anchorMidnight && avgMinutes >= 24 * 60 {
            avgMinutes -= 24 * 60
        }
        
        let avgH = (avgMinutes / 60) % 24
        let avgM = avgMinutes % 60
        return String(format: "%02dh%02d", avgH, avgM)
    }
    
    private func calculateRegularityScore(sessions: [SleepSession]) -> Int {
        guard sessions.count >= 2 else { return 85 }
        let calendar = Calendar.current
        let wakeMinutes = sessions.map { s -> Double in
            let h = calendar.component(.hour, from: s.endDate)
            let m = calendar.component(.minute, from: s.endDate)
            return Double(h * 60 + m)
        }
        let mean = wakeMinutes.reduce(0, +) / Double(wakeMinutes.count)
        let variance = wakeMinutes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(wakeMinutes.count)
        let standardDeviation = sqrt(variance) // en minutes
        
        // Si écart-type < 30min -> score > 90%
        let score = max(40, min(100, Int(100.0 - (standardDeviation * 0.6))))
        return score
    }
    
    private func buildWeeklyBars() -> [DailySleepBarData] {
        let calendar = Calendar.current
        var bars: [DailySleepBarData] = []
        let dayNames = ["Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"]
        
        for dayOffset in (0..<7).reversed() {
            guard let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let weekday = calendar.component(.weekday, from: dayDate) // 1 = Dimanche
            let label = dayNames[(weekday - 1) % 7]
            
            // Trouver la session correspondant à cette nuit
            let match = sessions.first { s in
                calendar.isDate(s.endDate, inSameDayAs: dayDate)
            }
            
            let duration = match?.durationHours ?? 0.0
            bars.append(DailySleepBarData(
                dayLabel: label,
                durationHours: duration,
                date: dayDate,
                isTargetReached: duration >= targetSleepHours
            ))
        }
        return bars
    }
    
    // MARK: - Calculateur de Cycles de Sommeil (90 min)
    
    /// Calcule les suggestions de réveil basées sur les cycles de 90 minutes
    public func calculateCircadianCycles(bedtime: Date = Date()) -> [SleepCycleSuggestion] {
        // En moyenne 14 minutes pour s'endormir
        let fallAsleepTime = bedtime.addingTimeInterval(14 * 60)
        let cycleDuration: TimeInterval = 90 * 60 // 1h30
        
        var suggestions: [SleepCycleSuggestion] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        // Cycles de 3 à 6 (4h30 à 9h de sommeil)
        for count in 3...6 {
            let wakeDate = fallAsleepTime.addingTimeInterval(Double(count) * cycleDuration)
            let totalHours = (Double(count) * 90) / 60.0
            let h = Int(totalHours)
            let m = Int((totalHours - Double(h)) * 60)
            let formattedSleep = "\(h)h\(m > 0 ? "\(m)" : "")"
            
            suggestions.append(SleepCycleSuggestion(
                cyclesCount: count,
                wakeUpTime: wakeDate,
                formattedTime: formatter.string(from: wakeDate),
                totalSleepFormatted: formattedSleep,
                isRecommended: count == 5 // 5 cycles = 7h30 (idéal recommandé)
            ))
        }
        return suggestions
    }
    
    // MARK: - Données Initiales de Démonstration
    
    private func createSampleSessions() -> [SleepSession] {
        let calendar = Calendar.current
        var list: [SleepSession] = []
        
        // Génère 5 nuits réalistes pour que le graphique et les moyennes soient parlants dès le départ
        let sampleDurations: [(hours: Int, minutes: Int, quality: Int)] = [
            (7, 45, 5),
            (8, 10, 4),
            (7, 20, 3),
            (8, 00, 5),
            (7, 35, 4)
        ]
        
        for (index, sample) in sampleDurations.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: -(index + 1), to: Date()) else { continue }
            var bedComps = calendar.dateComponents([.year, .month, .day], from: day)
            bedComps.hour = 23
            bedComps.minute = 15 + (index * 5)
            guard let start = calendar.date(from: bedComps) else { continue }
            let end = start.addingTimeInterval(Double(sample.hours * 3600 + sample.minutes * 60))
            
            list.append(SleepSession(
                startDate: start,
                endDate: end,
                targetDurationHours: 8.0,
                qualityRating: sample.quality,
                notes: nil
            ))
        }
        return list
    }
}
