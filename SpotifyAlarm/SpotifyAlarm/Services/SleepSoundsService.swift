import Foundation
import AVFoundation
import Combine

/// Type d'ambiance sonore pour l'endormissement
public enum SleepSoundType: String, CaseIterable, Identifiable {
    case rain = "Pluie douce"
    case waves = "Vagues océaniques"
    case whiteNoise = "Bruit blanc"
    case stream = "Ruisseau calme"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .waves: return "water.waves"
        case .whiteNoise: return "air.purifier"
        case .stream: return "drop.fill"
        }
    }
}

/// Service générateur de sons d'endormissement et de bruits blancs avec Sleep Timer automatique
@MainActor
public final class SleepSoundsService: ObservableObject {
    
    public static let shared = SleepSoundsService()
    
    @Published public var isPlaying: Bool = false
    @Published public var selectedSound: SleepSoundType = .rain
    @Published public var volume: Float = 0.6
    @Published public var remainingTimerMinutes: Int = 0
    @Published public var selectedTimerDuration: Int = 30 // 15, 30, 45 min
    
    private var audioEngine: AVAudioEngine?
    private var noiseNode: AVAudioSourceNode?
    private var sleepTimer: Timer?
    private var timerSecondsRemaining: Int = 0
    
    private init() {}
    
    // MARK: - Contrôle de Lecture
    
    public func togglePlayback() {
        if isPlaying {
            stop()
        } else {
            play(sound: selectedSound, durationMinutes: selectedTimerDuration)
        }
    }
    
    public func play(sound: SleepSoundType, durationMinutes: Int = 30) {
        stop()
        self.selectedSound = sound
        self.selectedTimerDuration = durationMinutes
        
        setupAudioEngine(for: sound)
        
        do {
            try audioEngine?.start()
            self.isPlaying = true
            startTimer(minutes: durationMinutes)
        } catch {
            print("Impossible de démarrer le son d'ambiance: \(error.localizedDescription)")
        }
    }
    
    public func stop() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        timerSecondsRemaining = 0
        remainingTimerMinutes = 0
        
        audioEngine?.stop()
        audioEngine = nil
        noiseNode = nil
        self.isPlaying = false
    }
    
    // MARK: - Minuteur d'Extinction (Sleep Timer)
    
    private func startTimer(minutes: Int) {
        sleepTimer?.invalidate()
        guard minutes > 0 else {
            remainingTimerMinutes = 0
            return
        }
        
        timerSecondsRemaining = minutes * 60
        remainingTimerMinutes = minutes
        
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.timerSecondsRemaining -= 1
            self.remainingTimerMinutes = max(0, self.timerSecondsRemaining / 60)
            
            // Extinction progressive lors des 30 dernières secondes
            if self.timerSecondsRemaining <= 30 && self.timerSecondsRemaining > 0 {
                let fadeFactor = Float(self.timerSecondsRemaining) / 30.0
                self.audioEngine?.mainMixerNode.outputVolume = self.volume * fadeFactor
            }
            
            if self.timerSecondsRemaining <= 0 {
                self.stop()
            }
        }
    }
    
    // MARK: - Générateur Audio Temporel (Synthèse Sonore Relaxante)
    
    private func setupAudioEngine(for sound: SleepSoundType) {
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        var wavePhase: Double = 0.0
        var filterState: Float = 0.0
        
        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for frame in 0..<Int(frameCount) {
                // Génération de bruit blanc initial (-1.0 à 1.0)
                let white = (Float.random(in: -1.0...1.0)) * 0.18
                
                // Filtrage passe-bas pour transformer le bruit blanc en son doux et chaud (bruit rose/brun)
                filterState = (filterState * 0.94) + (white * 0.06)
                var sample = filterState
                
                // Modulation cyclique selon le type de son
                switch sound {
                case .waves:
                    // Modulation lente façon ressac des vagues (cycle de 12 secondes)
                    let modulation = sin(wavePhase * 0.5) * 0.5 + 0.5
                    sample *= Float(modulation) * 1.6
                    wavePhase += 1.0 / 44100.0
                    
                case .rain:
                    // Petites variations aléatoires de densité de pluie
                    let drop = (Float.random(in: 0...100) > 98) ? Float.random(in: 0.05...0.2) : 0.0
                    sample = (sample * 0.8) + drop
                    
                case .stream:
                    // Modulation moyenne (ondulation d'eau)
                    let modulation = sin(wavePhase * 2.2) * 0.3 + 0.7
                    sample *= Float(modulation)
                    wavePhase += 1.0 / 44100.0
                    
                case .whiteNoise:
                    // Bruit doux régulier
                    sample *= 1.1
                }
                
                // Sortie stéréo
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = sample
                }
            }
            return noErr
        }
        
        self.noiseNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = volume
    }
}
