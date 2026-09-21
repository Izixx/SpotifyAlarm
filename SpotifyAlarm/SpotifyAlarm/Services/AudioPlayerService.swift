import Foundation
import AVFoundation
import AudioToolbox

/// Service de lecture audio locale pour les sonneries de réveil et le secours sonore.
/// Utilise la catégorie `.playback` pour sonner même si le commutateur silencieux physique est activé.
public final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    
    public static let shared = AudioPlayerService()
    
    @Published public var isPlaying: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var vibrationTimer: Timer?
    
    override private init() {
        super.init()
        configureAudioSession()
    }
    
    /// Configure la session audio pour contourner le mode silencieux matériel
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Erreur de configuration AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    /// Démarre la lecture de la sonnerie d'alarme
    /// - Parameters:
    ///   - soundName: Nom du fichier sonore sans extension (par défaut "alarm_sound")
    ///   - targetVolume: Volume maximal souhaité (0.0 à 1.0)
    ///   - fadeInDuration: Durée du fondu d'entrée en secondes pour un réveil progressif
    public func playAlarmSound(
        soundName: String = "alarm_sound",
        targetVolume: Float = 0.8,
        fadeInDuration: TimeInterval = 3.0
    ) {
        stopAlarmSound()
        
        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "wav") ??
                             Bundle.main.url(forResource: "alarm_sound", withExtension: "wav") else {
            print("Fichier audio d'alarme introuvable dans le bundle.")
            return
        }
        
        do {
            configureAudioSession()
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1 // Boucle infinie jusqu'à arrêt par l'utilisateur
            
            let safeTargetVolume = max(0.1, min(1.0, targetVolume))
            
            if fadeInDuration > 0 {
                audioPlayer?.volume = 0.05
                audioPlayer?.play()
                self.isPlaying = true
                
                // Fondu progressif
                let steps = 20
                let stepInterval = fadeInDuration / Double(steps)
                let volumeIncrement = (safeTargetVolume - 0.05) / Float(steps)
                var currentStep = 0
                
                fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
                    guard let self = self, let player = self.audioPlayer else {
                        timer.invalidate()
                        return
                    }
                    currentStep += 1
                    player.volume = min(safeTargetVolume, player.volume + volumeIncrement)
                    if currentStep >= steps {
                        player.volume = safeTargetVolume
                        timer.invalidate()
                        self.fadeTimer = nil
                    }
                }
            } else {
                audioPlayer?.volume = safeTargetVolume
                audioPlayer?.play()
                self.isPlaying = true
            }
            
            // Démarrage des vibrations continues
            startVibration()
        } catch {
            print("Erreur lors de la lecture audio: \(error.localizedDescription)")
        }
    }
    
    /// Arrête la sonnerie d'alarme et les vibrations
    public func stopAlarmSound() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        stopVibration()
        audioPlayer?.stop()
        audioPlayer = nil
        self.isPlaying = false
    }
    
    // MARK: - Vibrations
    
    private func startVibration() {
        stopVibration()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.async {
            self.vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
    
    private func stopVibration() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }
}
