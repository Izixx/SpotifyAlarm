import SwiftUI

/// Vue principale du Suivi du Sommeil : moyennes, statistiques, graphiques, cycles et ambiances sonores
public struct SleepTrackerView: View {
    @ObservedObject private var sleepService = SleepService.shared
    @ObservedObject private var soundsService = SleepSoundsService.shared
    @ObservedObject private var alarmService = AlarmService.shared
    @ObservedObject private var analysisService = SleepAnalysisService.shared
    
    @State private var isAddManualPresented: Bool = false
    @State private var selectedSessionForHypnogram: SleepSession? = nil
    @State private var showAlarmCreatedAlert: Bool = false
    @State private var createdAlarmMessage: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 1. Carte de Session Active ou Démarrage Rapide
                        activeSessionBanner
                        
                        // 2. Grille des 4 Moyennes Clés
                        statsCardsGrid
                        
                        // 3. Graphique Hebdomadaire
                        weeklySleepChartCard
                        
                        // 4. Calculateur de Cycles de Sommeil (90 min)
                        circadianCyclesCard
                        
                        // 5. Ambiances d'Endormissement & Bruits Blancs
                        sleepSoundsCard
                        
                        // 6. Historique des Nuits
                        sleepHistorySection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Mon Sommeil")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        isAddManualPresented = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $isAddManualPresented) {
                AddManualSleepView()
            }
            .sheet(item: $selectedSessionForHypnogram) { session in
                HypnogramView(session: session)
            }
            .alert("Alarme Programmée", isPresented: $showAlarmCreatedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(createdAlarmMessage)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - 1. Carte de Session Active
    
    private var activeSessionBanner: some View {
        Group {
            if let start = sleepService.activeSessionStart {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(red: 0.6, green: 0.3, blue: 1.0))
                            .frame(width: 10, height: 10)
                        
                        Text("ANALYSE DU SOMMEIL EN DIRECT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.7, green: 0.5, blue: 1.0))
                        
                        Spacer()
                        
                        Text("Coucher à \(formatTime(start))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Indicateurs en direct (Capteurs & Phase)
                    HStack(spacing: 12) {
                        // Badge de phase actuelle
                        HStack(spacing: 6) {
                            Image(systemName: analysisService.currentStage.systemIcon)
                                .font(.system(size: 13))
                            Text(analysisService.currentStage.displayName)
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(Color(hex: analysisService.currentStage.colorHex))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.1))
                        .cornerRadius(10)
                        
                        Spacer()
                        
                        // Niveau Sonore
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.cyan)
                            Text("\(Int(analysisService.currentDecibels)) dB")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        
                        // Ronflement
                        if analysisService.currentSnoreMinutes > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                Text("\(analysisService.currentSnoreMinutes)m ronfl.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Capteurs actifs 🌙")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Les phases et bruits sont enregistrés pour votre hypnogramme.")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            let results = analysisService.finishAnalysis()
                            _ = sleepService.endSleepSession(
                                at: Date(),
                                quality: 4,
                                stages: results.stages,
                                snoreMinutes: results.snoreMinutes,
                                snoreEpisodes: results.snoreEpisodes,
                                averageDB: results.averageDB,
                                calculatedScore: results.sleepScore
                            )
                        }) {
                            Text("☀️ Je me réveille")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.yellow)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(16)
                .background(Color(red: 0.15, green: 0.12, blue: 0.25))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.6, green: 0.3, blue: 1.0).opacity(0.3), lineWidth: 1)
                )
            } else {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.114, green: 0.725, blue: 0.329).opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Prêt pour la nuit ?")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Lancez le suivi ou ouvrez le Mode Chevet")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        sleepService.startSleepSession()
                        analysisService.startAnalysis()
                    }) {
                        Text("Démarrer")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.114, green: 0.725, blue: 0.329))
                            .cornerRadius(18)
                    }
                }
                .padding(16)
                .background(Color(white: 0.12))
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - 2. Grille des 4 Moyennes Clés
    
    private var statsCardsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MOYENNES & RÉGULARITÉ")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(
                    icon: "clock.fill",
                    color: Color(red: 0.114, green: 0.725, blue: 0.329),
                    title: "Durée moyenne",
                    value: sleepService.stats.formattedAverageDuration,
                    subtitle: "Objectif : \(Int(sleepService.targetSleepHours))h / nuit"
                )
                
                statCard(
                    icon: "bed.double.fill",
                    color: Color(red: 0.6, green: 0.4, blue: 1.0),
                    title: "Coucher moyen",
                    value: sleepService.stats.averageBedtimeString,
                    subtitle: "Sur les 7 derniers jours"
                )
                
                statCard(
                    icon: "sunrise.fill",
                    color: Color.orange,
                    title: "Réveil moyen",
                    value: sleepService.stats.averageWakeTimeString,
                    subtitle: "Heure moyenne levée"
                )
                
                statCard(
                    icon: "chart.bar.xaxis",
                    color: Color.blue,
                    title: "Régularité",
                    value: "\(sleepService.stats.regularityScore) %",
                    subtitle: sleepService.stats.regularityScore > 80 ? "Excellente régularité" : "Rythme variable"
                )
            }
        }
    }
    
    private func statCard(icon: String, color: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.8))
                .lineLimit(1)
        }
        .padding(14)
        .background(Color(white: 0.12))
        .cornerRadius(14)
    }
    
    // MARK: - 3. Graphique Hebdomadaire
    
    private var weeklySleepChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("HISTORIQUE DES 7 DERNIERS JOURS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                Spacer()
                Text("Ligne repère : \(Int(sleepService.targetSleepHours))h")
                    .font(.caption2)
                    .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
            }
            
            // Barres de sommeil
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(sleepService.stats.weeklyBars) { bar in
                    VStack(spacing: 6) {
                        // Valeur en haut
                        if bar.durationHours > 0 {
                            Text(String(format: "%.1fh", bar.durationHours))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                        } else {
                            Text("-")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        
                        // Barre verticale
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Color(white: 0.2))
                                .frame(width: 22, height: 110)
                            
                            let height = max(4.0, min(110.0, (bar.durationHours / 10.0) * 110.0))
                            Capsule()
                                .fill(bar.isTargetReached ? Color(red: 0.114, green: 0.725, blue: 0.329) : Color(red: 0.4, green: 0.45, blue: 0.9))
                                .frame(width: 22, height: height)
                        }
                        
                        // Label du jour
                        Text(bar.dayLabel)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150)
            .padding(.vertical, 4)
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(16)
    }
    
    // MARK: - 4. Calculateur de Cycles Circadiens (90 min)
    
    private var circadianCyclesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(Color.yellow)
                Text("CYCLES DE SOMMEIL OPTIMAUX (90 MIN)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }
            
            Text("Pour vous réveiller frais et dispos, réglez votre réveil à la fin d'un cycle naturel de 90 minutes :")
                .font(.caption)
                .foregroundColor(Color(white: 0.8))
            
            let suggestions = sleepService.calculateCircadianCycles(bedtime: Date())
            VStack(spacing: 8) {
                ForEach(suggestions) { cycle in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("\(cycle.cyclesCount) cycles (\(cycle.totalSleepFormatted))")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                if cycle.isRecommended {
                                    Text("RECOMMANDÉ ⭐")
                                        .font(.system(size: 9, weight: .black))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 0.114, green: 0.725, blue: 0.329))
                                        .foregroundColor(.black)
                                        .cornerRadius(6)
                                }
                            }
                            Text("Réveil optimal à \(cycle.formattedTime)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            createAlarmForCycle(cycle)
                        }) {
                            Text("Régler réveil")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.114, green: 0.725, blue: 0.329).opacity(0.15))
                                .cornerRadius(10)
                        }
                    }
                    .padding(10)
                    .background(Color(white: 0.16))
                    .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(16)
    }
    
    // MARK: - 5. Ambiances Sonores d'Endormissement & Bruits Blancs
    
    private var sleepSoundsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "air.purifier")
                    .foregroundColor(Color.cyan)
                Text("AMBIANCES D'ENDORMISSEMENT & BRUITS BLANCS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }
            
            // Sélection du son
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SleepSoundType.allCases) { sound in
                        let isSelected = soundsService.selectedSound == sound
                        Button(action: {
                            soundsService.play(sound: sound, durationMinutes: soundsService.selectedTimerDuration)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: sound.iconName)
                                Text(sound.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isSelected && soundsService.isPlaying ? Color.cyan.opacity(0.3) : Color(white: 0.18))
                            .foregroundColor(isSelected && soundsService.isPlaying ? Color.cyan : .white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected && soundsService.isPlaying ? Color.cyan : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            
            // Contrôle et minuteur
            HStack(spacing: 14) {
                Button(action: {
                    soundsService.togglePlayback()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: soundsService.isPlaying ? "pause.fill" : "play.fill")
                        Text(soundsService.isPlaying ? "Arrêter l'ambiance" : "Lancer l'ambiance")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.cyan)
                    .cornerRadius(14)
                }
                
                Spacer()
                
                // Sleep Timer
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundColor(.gray)
                    
                    if soundsService.isPlaying && soundsService.remainingTimerMinutes > 0 {
                        Text("\(soundsService.remainingTimerMinutes)m restantes")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Color.cyan)
                    } else {
                        Menu {
                            Button("15 minutes") { soundsService.selectedTimerDuration = 15 }
                            Button("30 minutes") { soundsService.selectedTimerDuration = 30 }
                            Button("45 minutes") { soundsService.selectedTimerDuration = 45 }
                            Button("60 minutes") { soundsService.selectedTimerDuration = 60 }
                        } label: {
                            Text("Timer: \(soundsService.selectedTimerDuration)m")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(16)
    }
    
    // MARK: - 6. Historique des Nuits
    
    private var sleepHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HISTORIQUE DES NUITS (\(sleepService.sessions.count))")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
            
            if sleepService.sessions.isEmpty {
                Text("Aucune nuit enregistrée pour l'instant.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(16)
            } else {
                VStack(spacing: 8) {
                    ForEach(sleepService.sessions.prefix(10)) { session in
                        HStack(spacing: 12) {
                            Button(action: {
                                selectedSessionForHypnogram = session
                            }) {
                                HStack(spacing: 12) {
                                    // Badge Score
                                    ZStack {
                                        Circle()
                                            .fill(scoreBgColor(session.displaySleepScore))
                                            .frame(width: 38, height: 38)
                                        Text("\(session.displaySleepScore)")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(session.formattedNightSummary)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                            
                                            Image(systemName: "waveform.path.ecg")
                                                .font(.system(size: 10))
                                                .foregroundColor(.purple)
                                        }
                                        
                                        HStack(spacing: 6) {
                                            Text("\(session.formattedStartTime) → \(session.formattedEndTime)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text(session.sleepScoreVerdict)
                                                .font(.caption2)
                                                .foregroundColor(.gray.opacity(0.8))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text(session.formattedDuration)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(session.durationHours >= session.targetDurationHours ? Color(red: 0.114, green: 0.725, blue: 0.329) : .white)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                sleepService.deleteSession(id: session.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.leading, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color(white: 0.12))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func createAlarmForCycle(_ cycle: SleepCycleSuggestion) {
        let newAlarm = Alarm(
            title: "Réveil Cycle (\(cycle.totalSleepFormatted))",
            time: cycle.wakeUpTime,
            repeatDays: [],
            spotifyItem: nil,
            volume: 0.8,
            isEnabled: true
        )
        alarmService.saveAlarm(newAlarm)
        createdAlarmMessage = "Une alarme a été programmée à \(cycle.formattedTime) pour vous réveiller après \(cycle.cyclesCount) cycles complets (\(cycle.totalSleepFormatted))."
        showAlarmCreatedAlert = true
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func scoreBgColor(_ score: Int) -> Color {
        switch score {
        case 85...100: return Color(red: 0.114, green: 0.725, blue: 0.329).opacity(0.3)
        case 75..<85:  return Color.blue.opacity(0.3)
        case 65..<75:  return Color.orange.opacity(0.3)
        default:       return Color.red.opacity(0.3)
        }
    }
}

// MARK: - Vue d'Ajout Manuel de Nuit

public struct AddManualSleepView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bedtime: Date = Calendar.current.date(byAdding: .hour, value: -8, to: Date()) ?? Date()
    @State private var wakeTime: Date = Date()
    @State private var quality: Int = 4
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Horaires du sommeil")) {
                    DatePicker("Heure de coucher", selection: $bedtime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Heure de réveil", selection: $wakeTime, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Qualité ressentie")) {
                    Picker("Qualité", selection: $quality) {
                        Text("⭐ Mauvais (1/5)").tag(1)
                        Text("⭐⭐ Moyen (2/5)").tag(2)
                        Text("⭐⭐⭐ Bon (3/5)").tag(3)
                        Text("⭐⭐⭐⭐ Très bon (4/5)").tag(4)
                        Text("⭐⭐⭐⭐⭐ Parfait (5/5)").tag(5)
                    }
                }
            }
            .navigationTitle("Ajouter une nuit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        if wakeTime > bedtime {
                            SleepService.shared.addManualSession(
                                startDate: bedtime,
                                endDate: wakeTime,
                                quality: quality
                            )
                            dismiss()
                        }
                    }
                    .disabled(wakeTime <= bedtime)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Extension Couleur Hex

fileprivate extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

