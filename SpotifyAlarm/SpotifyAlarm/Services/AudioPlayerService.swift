import Foundation
import AVFoundation
import AudioToolbox
import UIKit

/// Service de lecture audio locale pour les sonneries de réveil, fichiers MP3 importés et vibrations haptiques rythmées.
/// Utilise la catégorie `.playback` pour contourner le commutateur silencieux physique.
public final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    
    public static let shared = AudioPlayerService()
    
    @Published public var isPlaying: Bool = false
    @Published public var isPreviewing: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var vibrationTimer: Timer?
    private var beatTimer: Timer?
    
    // Historique glissant pour l'algorithme de détection de rythme (Beat Detection)
    private var energyHistory: [Float] = []
    private var lastBeatTime: TimeInterval = 0
    private let hapticImpact = UIImpactFeedbackGenerator(style: .heavy)
    
    override private init() {
        super.init()
        configureAudioSession()
        hapticImpact.prepare()
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
    
    // MARK: - Lecture Alarme avec Fichier Audio Personnalisé (MP3 / M4A / WAV)
    
    /// Démarre la lecture d'un fichier audio importé par l'utilisateur
    public func playCustomAudio(
        fileName: String,
        targetVolume: Float = 0.8,
        fadeInDuration: TimeInterval = 3.0,
        vibrateOnBeat: Bool = true
    ) {
        guard let fileURL = CustomAudioService.shared.fileURL(for: fileName) else {
            print("Fichier audio personnalisé introuvable: \(fileName). Basculement sur le son par défaut.")
            playAlarmSound(targetVolume: targetVolume, fadeInDuration: fadeInDuration, vibrateOnBeat: vibrateOnBeat)
            return
        }
        
        playAudioFromURL(fileURL: fileURL, targetVolume: targetVolume, fadeInDuration: fadeInDuration, vibrateOnBeat: vibrateOnBeat)
    }
    
    /// Démarre la lecture de la sonnerie d'alarme standard (WAV)
    public func playAlarmSound(
        soundName: String = "alarm_sound",
        targetVolume: Float = 0.8,
        fadeInDuration: TimeInterval = 3.0,
        vibrateOnBeat: Bool = true
    ) {
        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "wav") ??
                             Bundle.main.url(forResource: "alarm_sound", withExtension: "wav") else {
            print("Fichier audio d'alarme introuvable dans le bundle.")
            return
        }
        
        playAudioFromURL(fileURL: soundURL, targetVolume: targetVolume, fadeInDuration: fadeInDuration, vibrateOnBeat: vibrateOnBeat)
    }
    
    // MARK: - Moteur de Lecture Commun & Beat Sync
    
    private func playAudioFromURL(
        fileURL: URL,
        targetVolume: Float,
        fadeInDuration: TimeInterval,
        vibrateOnBeat: Bool
    ) {
        stopAlarmSound()
        
        do {
            configureAudioSession()
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.delegate = self
            player.numberOfLoops = -1 // Boucle continue jusqu'à l'arrêt par l'utilisateur
            player.isMeteringEnabled = true // Active l'analyse audio en temps réel
            self.audioPlayer = player
            
            let safeTargetVolume = max(0.1, min(1.0, targetVolume))
            
            if fadeInDuration > 0 {
                player.volume = 0.05
                player.play()
                self.isPlaying = true
                
                // Fondu progressif du volume
                let steps = 20
                let stepInterval = fadeInDuration / Double(steps)
                let volumeIncrement = (safeTargetVolume - 0.05) / Float(steps)
                var currentStep = 0
                
                fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
                    guard let self = self, let p = self.audioPlayer else {
                        timer.invalidate()
                        return
                    }
                    currentStep += 1
                    p.volume = min(safeTargetVolume, p.volume + volumeIncrement)
                    if currentStep >= steps {
                        p.volume = safeTargetVolume
                        timer.invalidate()
                        self.fadeTimer = nil
                    }
                }
            } else {
                player.volume = safeTargetVolume
                player.play()
                self.isPlaying = true
            }
            
            // Démarrage de la vibration (soit calée sur le rythme musical, soit standard)
            if vibrateOnBeat {
                startBeatDetection(player: player)
            } else {
                startConstantVibration()
            }
        } catch {
            print("Erreur lors de la lecture audio: \(error.localizedDescription)")
            // En cas d'échec de lecture, vibrations de sécurité
            startConstantVibration()
        }
    }
    
    /// Arrête la sonnerie d'alarme et toutes les vibrations
    public func stopAlarmSound() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        stopBeatDetection()
        stopConstantVibration()
        audioPlayer?.stop()
        audioPlayer = nil
        self.isPlaying = false
    }
    
    // MARK: - Détection de Battement Audio (Beat Detection & Haptic Sync)
    
    /// Démarre l'analyse audio en direct pour faire vibrer le téléphone au rythme de la musique
    private func startBeatDetection(player: AVAudioPlayer) {
        stopBeatDetection()
        stopConstantVibration()
        
        energyHistory.removeAll()
        lastBeatTime = 0
        hapticImpact.prepare()
        
        // Échantillonnage à 25 Hz (toutes les 40 ms)
        beatTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self = self, let p = self.audioPlayer, p.isPlaying else { return }
            p.updateMeters()
            
            let avgPower = p.averagePower(forChannel: 0) // de -160 dB à 0 dB
            let peakPower = p.peakPower(forChannel: 0)
            
            // Convertit en échelle d'énergie linéaire approximative 0.0 à 1.0
            let linearPower = max(0.0, (avgPower + 50.0) / 50.0)
            let peakLinear = max(0.0, (peakPower + 40.0) / 40.0)
            
            // Maintient une moyenne glissante sur les 15 derniers échantillons (~0.6s)
            self.energyHistory.append(linearPower)
            if self.energyHistory.count > 15 {
                self.energyHistory.removeFirst()
            }
            let averageEnergy = self.energyHistory.reduce(0, +) / Float(max(1, self.energyHistory.count))
            
            let now = CACurrentMediaTime()
            let timeSinceLastBeat = now - self.lastBeatTime
            
            // Détection de transitoire / coup de basse :
            // 1. Énergie instantanée nettement supérieure à la moyenne locale (front montant)
            // 2. Ou pic de puissance sonore au-dessus d'un seuil fort
            // 3. Cooldown minimal de 180 ms (limite à ~300 BPM max pour des vibrations distinctes et nettes)
            let isTransient = (linearPower > averageEnergy * 1.35 && linearPower > 0.25) || (peakLinear > 0.85)
            
            if isTransient && timeSinceLastBeat > 0.18 {
                self.lastBeatTime = now
                self.triggerRhythmicHaptic(intensity: min(1.0, Double(linearPower)))
            }
        }
    }
    
    private func stopBeatDetection() {
        beatTimer?.invalidate()
        beatTimer = nil
        energyHistory.removeAll()
    }
    
    /// Déclenche une impulsion haptique rythmée calibrée
    private func triggerRhythmicHaptic(intensity: Double) {
        hapticImpact.impactOccurred(intensity: CGFloat(max(0.6, intensity)))
        
        // Toutes les ~400ms si le battement est très marqué, renforce avec le moteur haptique système
        if intensity > 0.75 {
            AudioServicesPlaySystemSound(1519) // Impulsion haptique sèche et percutante (Actuate "Peek")
        }
    }
    
    // MARK: - Pulsations Rythmiques Autonomes (ex: pour Spotify ou mode chevet)
    
    /// Démarre une pulsation haptique cadencée sur un tempo musical dynamique (124 BPM par défaut)
    public func startRhythmicPulse(tempoBPM: Double = 124.0) {
        stopConstantVibration()
        stopBeatDetection()
        
        let interval = 60.0 / tempoBPM // ~0.484s pour 124 BPM
        hapticImpact.prepare()
        
        triggerRhythmicHaptic(intensity: 1.0)
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.triggerRhythmicHaptic(intensity: 0.9)
        }
    }
    
    /// Démarre uniquement les vibrations continues classiques
    public func startVibrationOnly() {
        startRhythmicPulse(tempoBPM: 124.0)
    }
    
    private func startConstantVibration() {
        stopConstantVibration()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.async {
            self.vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
    
    private func stopConstantVibration() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }
    
    // MARK: - Pré-écoute Audio (pour le sélecteur MP3)
    
    /// Lance la pré-écoute courte d'un fichier audio
    public func playPreview(fileURL: URL) {
        stopPreview()
        do {
            configureAudioSession()
            previewPlayer = try AVAudioPlayer(contentsOf: fileURL)
            previewPlayer?.delegate = self
            previewPlayer?.volume = 0.8
            previewPlayer?.play()
            self.isPreviewing = true
        } catch {
            print("Erreur de pré-écoute: \(error.localizedDescription)")
        }
    }
    
    /// Arrête la pré-écoute
    public func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        self.isPreviewing = false
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player == previewPlayer {
            self.isPreviewing = false
            self.previewPlayer = nil
        }
    }
}
