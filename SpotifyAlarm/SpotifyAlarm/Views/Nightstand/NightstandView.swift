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
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @ObservedObject private var alarmService = AlarmService.shared
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
        }
        .onDisappear {
            // Restaure la mise en veille standard
            UIApplication.shared.isIdleTimerDisabled = false
            audioPlayerService.stopAlarmSound()
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
                    Text("Prochain réveil à \(alarm.formattedTime)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
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
    
    // MARK: - Bannière de Sonnerie Active
    
    private func activeRingingBanner(for alarm: Alarm) -> some View {
        VStack(spacing: 16) {
            Text("⏰ IL EST L'HEURE !")
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
            
            Text(alarm.musicDescription)
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                Button(action: {
                    if let item = alarm.spotifyItem {
                        spotifyAPIService.openSpotifyApp(uri: item.uri)
                    }
                    audioPlayerService.stopAlarmSound()
                }) {
                    Text("🎵 Ouvrir Spotify")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.114, green: 0.725, blue: 0.329))
                        .cornerRadius(24)
                }
                
                Button(action: {
                    audioPlayerService.stopAlarmSound()
                    triggeredAlarm = nil
                }) {
                    Text("Arrêter")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
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
                    triggerAlarmNow(alarm)
                    break
                }
            }
        }
    }
    
    private func triggerAlarmNow(_ alarm: Alarm) {
        triggeredAlarm = alarm
        // 1. Jouer la sonnerie d'alarme
        audioPlayerService.playAlarmSound(targetVolume: alarm.volume, fadeInDuration: 3.0)
        
        // 2. Déclencher Spotify si configuré
        if let item = alarm.spotifyItem {
            Task {
                try? await spotifyAPIService.triggerPlayback(item: item)
            }
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
