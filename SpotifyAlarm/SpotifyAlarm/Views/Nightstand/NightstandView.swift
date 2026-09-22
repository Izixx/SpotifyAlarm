import SwiftUI
import Combine

/// Mode Chevet (Nightstand Mode) : horloge nocturne plein écran maintenant l'application éveillée.
/// Permet un réveil 100% direct avec démarrage instantané de Spotify à l'heure programmée.
@MainActor
public struct NightstandView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentTime = Date()
    @State private var isDimmed = false
    @State private var triggeredAlarm: Alarm? = nil
    @State private var isSmartAlarmTriggered = false
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @ObservedObject private var alarmService = AlarmService.shared
    @ObservedObject private var analysisService = SleepAnalysisService.shared
    private let audioPlayerService = AudioPlayerService.shared
    private let spotifyAPIService = SpotifyAPIService.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Barre supérieure : Bouton Tamiser & Quitter
                HStack {
                    Button(action: {
                        withAnimation {
                            isDimmed.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isDimmed ? "moon.fill" : "sun.max.fill")
                            Text(isDimmed ? "Écran tamisé" : "Normal")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.15))
                        .foregroundColor(.gray)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Horloge Principale
                VStack(spacing: 8) {
                    Text(timeFormatter.string(from: currentTime))
                        .font(.system(size: 84, weight: .thin, design: .rounded))
                        .foregroundColor(isDimmed ? .gray.opacity(0.4) : .white)
                    
                    Text(dateFormatter.string(from: currentTime).capitalized)
                        .font(.title3)
                        .foregroundColor(isDimmed ? .gray.opacity(0.3) : .gray)
                    
                    liveSleepHUD
                        .padding(.top, 6)
                }
                
                Spacer()
                
                // État de l'alarme ou alerte de réveil
                if let alarm = triggeredAlarm {
                    // Alarme en cours de sonnerie !
                    activeRingingBanner(for: alarm)
                } else {
                    nextAlarmInfoCard
                }
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Empêche la mise en veille automatique tant que le mode chevet est affiché
            UIApplication.shared.isIdleTimerDisabled = true
            SleepService.shared.startSleepSession()
            analysisService.startAnalysis()
        }
        .onDisappear {
            // Restaure la mise en veille standard
            UIApplication.shared.isIdleTimerDisabled = false
            audioPlayerService.stopAlarmSound()
            let results = analysisService.finishAnalysis()
            _ = SleepService.shared.endSleepSession(
                quality: 4,
                stages: results.stages,
                snoreMinutes: results.snoreMinutes,
                snoreEpisodes: results.snoreEpisodes,
                averageDB: results.averageDB,
                calculatedScore: results.sleepScore
            )
        }
        .onReceive(timer) { newTime in
            self.currentTime = newTime
            checkAlarmTrigger(at: newTime)
        }
    }
    
    // MARK: - Carte de Prochaine Alarme
    
    private var nextAlarmInfoCard: some View {
        let activeAlarms = alarmService.alarms.filter { $0.isEnabled }
        let nextAlarm = activeAlarms
            .compactMap { alarm -> (Alarm, Date)? in
                guard let next = alarm.nextTriggerDate() else { return nil }
                return (alarm, next)
            }
            .min(by: { $0.1 < $1.1 })
        
        return HStack(spacing: 12) {
            Image(systemName: "alarm.fill")
                .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                .font(.system(size: 20))
            
            if let (alarm, _) = nextAlarm {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Prochain réveil à \(alarm.formattedTime)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        if alarm.isSmartAlarmEnabled {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text(alarm.musicDescription)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                Text("Aucune alarme active")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(white: 0.12))
        .cornerRadius(20)
        .opacity(isDimmed ? 0.4 : 1.0)
    }
    
    // MARK: - HUD de Sommeil en Direct
    
    private var liveSleepHUD: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: analysisService.currentStage.colorHex))
                    .frame(width: 8, height: 8)
                Text(analysisService.currentStage.displayName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("•")
                .foregroundColor(.gray.opacity(0.5))
            
            HStack(spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.cyan)
                Text("\(Int(analysisService.currentDecibels)) dB")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if analysisService.currentSnoreMinutes > 0 {
                Text("•")
                    .foregroundColor(.gray.opacity(0.5))
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                    Text("\(analysisService.currentSnoreMinutes)m")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .opacity(isDimmed ? 0.3 : 0.9)
    }
    
    // MARK: - Bannière de Sonnerie Active
    
    private func activeRingingBanner(for alarm: Alarm) -> some View {
        VStack(spacing: 16) {
            if isSmartAlarmTriggered {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("RÉVEIL INTELLIGENT • Sommeil Léger")
                }
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.yellow)
                .cornerRadius(12)
            }
            
            Text("⏰ IL EST L'HEURE !")
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
            
            Text(alarm.musicDescription)
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                if alarm.spotifyItem != nil {
                    Button(action: {
                        if let item = alarm.spotifyItem {
                            spotifyAPIService.openSpotifyApp(uri: item.uri)
                        }
                        audioPlayerService.stopAlarmSound()
                        isSmartAlarmTriggered = false
                    }) {
                        Text("🎵 Ouvrir Spotify")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.114, green: 0.725, blue: 0.329))
                            .cornerRadius(24)
                    }
                }
                
                Button(action: {
                    audioPlayerService.stopAlarmSound()
                    triggeredAlarm = nil
                    isSmartAlarmTriggered = false
                }) {
                    Text("Arrêter")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(white: 0.2))
                        .cornerRadius(24)
                }
            }
        }
        .padding(24)
        .background(Color(white: 0.15))
        .cornerRadius(24)
    }
    
    // MARK: - Détection de Déclenchement
    
    private func checkAlarmTrigger(at date: Date) {
        // 1. Vérification prioritaire du Réveil Intelligent (Smart Alarm)
        if let smartAlarm = analysisService.checkSmartAlarmTrigger(alarms: alarmService.alarms, at: date) {
            triggerAlarmNow(smartAlarm, isSmart: true)
            return
        }
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let currentSecond = calendar.component(.second, from: date)
        
        // Déclenchement à la seconde 0 de la minute correspondante
        guard currentSecond == 0 else { return }
        
        let weekday = RepeatDay(rawValue: calendar.component(.weekday, from: date))
        
        for alarm in alarmService.alarms where alarm.isEnabled {
            let (h, m) = alarm.timeComponents
            if h == currentHour && m == currentMinute {
                // Vérifier si répétition ou ponctuel
                if alarm.repeatDays.isEmpty || (weekday != nil && alarm.repeatDays.contains(weekday!)) {
                    triggerAlarmNow(alarm, isSmart: false)
                    break
                }
            }
        }
    }
    
    private func triggerAlarmNow(_ alarm: Alarm, isSmart: Bool = false) {
        self.triggeredAlarm = alarm
        self.isSmartAlarmTriggered = isSmart
        
        if let item = alarm.spotifyItem {
            // Uniquement la musique Spotify + pulsations cadencées
            audioPlayerService.startVibrationOnly()
            
            Task {
                do {
                    try await spotifyAPIService.triggerPlayback(item: item)
                } catch {
                    print("Secours sonore activé car Spotify n'a pas pu démarrer: \(error.localizedDescription)")
                    audioPlayerService.playAlarmSound(
                        targetVolume: alarm.volume,
                        fadeInDuration: 2.0,
                        vibrateOnBeat: alarm.vibrateOnBeat
                    )
                }
            }
        } else if let customFileName = alarm.customAudioFileName, !customFileName.isEmpty {
            audioPlayerService.playCustomAudio(
                fileName: customFileName,
                targetVolume: alarm.volume,
                fadeInDuration: 2.5,
                vibrateOnBeat: alarm.vibrateOnBeat
            )
        } else {
            audioPlayerService.playAlarmSound(
                targetVolume: alarm.volume,
                fadeInDuration: 3.0,
                vibrateOnBeat: alarm.vibrateOnBeat
            )
        }
    }
    
    // MARK: - Formateurs
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
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
