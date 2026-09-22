import Foundation
import Combine
import AVFoundation
import CoreMotion
import UIKit

/// Service d'analyse avancée du sommeil en temps réel
/// Utilise le microphone (acoustique & ronflements) et l'accéléromètre (mouvements)
@MainActor
public final class SleepAnalysisService: ObservableObject {
    
    public static let shared = SleepAnalysisService()
    
    // MARK: - Propriétés Publiées
    
    @Published public var isAnalyzing: Bool = false
    @Published public var currentStage: SleepStage = .light
    @Published public var currentDecibels: Double = 30.0
    @Published public var currentMotion: Double = 0.0
    @Published public var currentSnoreMinutes: Int = 0
    @Published public var snoreEpisodes: Int = 0
    @Published public var recordedEpochs: [SleepStageEpoch] = []
    @Published public var isMicrophonePermissionGranted: Bool = false
    @Published public var smartAlarmTriggered: Bool = false
    
    // MARK: - Capteurs & Moteurs
    
    private var audioRecorder: AVAudioRecorder?
    private let motionManager = CMMotionManager()
    private var analysisTimer: Timer?
    private var sessionStartTime: Date?
    
    // Tampons de calcul
    private var soundSamples: [Double] = []
    private var motionSamples: [Double] = []
    private var snoreStreakSeconds: Int = 0
    private var totalSnoreSeconds: Int = 0
    private var lastEpochTime: Date = Date()
    private var epochIntervalSeconds: TimeInterval = 60.0 // 1 époque par minute
    
    private init() {
        checkMicrophonePermission()
    }
    
    // MARK: - Permissions
    
    public func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            self.isMicrophonePermissionGranted = true
        case .denied:
            self.isMicrophonePermissionGranted = false
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.isMicrophonePermissionGranted = granted
                }
            }
        @unknown default:
            self.isMicrophonePermissionGranted = false
        }
    }
    
    // MARK: - Démarrage de l'Analyse
    
    public func startAnalysis() {
        guard !isAnalyzing else { return }
        
        self.sessionStartTime = Date()
        self.lastEpochTime = Date()
        self.recordedEpochs = []
        self.soundSamples = []
        self.motionSamples = []
        self.snoreStreakSeconds = 0
        self.totalSnoreSeconds = 0
        self.currentSnoreMinutes = 0
        self.snoreEpisodes = 0
        self.smartAlarmTriggered = false
        self.currentStage = .awake // Au début, l'utilisateur est éveillé
        
        setupAudioMonitoring()
        setupMotionMonitoring()
        
        // Ajout d'une première époque
        let initialEpoch = SleepStageEpoch(
            timestamp: Date(),
            stage: .awake,
            soundLevelDB: 30.0,
            motionIntensity: 0.1
        )
        self.recordedEpochs.append(initialEpoch)
        
        self.isAnalyzing = true
        
        // Timer d'échantillonnage régulier (toutes les 1.5 secondes)
        analysisTimer?.invalidate()
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sampleSensorsTick()
            }
        }
    }
    
    // MARK: - Configuration Audio
    
    private func setupAudioMonitoring() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let tempDir = FileManager.default.temporaryDirectory
            let audioURL = tempDir.appendingPathComponent("sleep_monitor_temp.m4a")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
        } catch {
            print("Erreur initialisation micro pour l'analyse: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Configuration Accéléromètre
    
    private func setupMotionMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let d = data else { return }
            // Calcul de la magnitude de l'accélération relative à 1G
            let magnitude = sqrt(d.acceleration.x * d.acceleration.x +
                                 d.acceleration.y * d.acceleration.y +
                                 d.acceleration.z * d.acceleration.z)
            let delta = abs(magnitude - 1.0)
            self.currentMotion = min(1.0, delta * 3.0)
            self.motionSamples.append(self.currentMotion)
        }
    }
    
    // MARK: - Boucle d'Échantillonnage (Tick 1.5s)
    
    private func sampleSensorsTick() {
        guard isAnalyzing else { return }
        
        // 1. Lecture acoustique
        var currentDB: Double = 30.0
        if let recorder = audioRecorder, recorder.isRecording {
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0) // de -160 à 0 dBFS
            // Conversion approximative en dB SPL (20 à 90 dB)
            currentDB = max(20.0, min(95.0, Double(power) + 95.0))
        }
        self.currentDecibels = currentDB
        self.soundSamples.append(currentDB)
        
        // 2. Détection des ronflements
        // Les ronflements se situent généralement entre 44 et 68 dB avec une régularité respiratoire
        if currentDB >= 44.0 && currentDB <= 70.0 && currentMotion < 0.05 {
            snoreStreakSeconds += 2
            if snoreStreakSeconds >= 6 { // Au moins 6 secondes continues de sons rythmés
                totalSnoreSeconds += 2
                self.currentSnoreMinutes = totalSnoreSeconds / 60
                if snoreStreakSeconds == 6 {
                    self.snoreEpisodes += 1
                }
            }
        } else {
            snoreStreakSeconds = 0
        }
        
        // 3. Clôture d'une époque (toutes les 60 secondes)
        let now = Date()
        if now.timeIntervalSince(lastEpochTime) >= epochIntervalSeconds {
            evaluateAndRecordEpoch(at: now)
            lastEpochTime = now
        }
    }
    
    // MARK: - Évaluation d'une Époque & Algorithme Circadien
    
    private func evaluateAndRecordEpoch(at date: Date) {
        guard let start = sessionStartTime else { return }
        
        let elapsedMinutes = date.timeIntervalSince(start) / 60.0
        
        // Moyenne sonore et de mouvement sur l'époque
        let recentSounds = soundSamples.suffix(40)
        let avgSound = recentSounds.isEmpty ? 30.0 : recentSounds.reduce(0.0, +) / Double(recentSounds.count)
        
        let recentMotions = motionSamples.suffix(40)
        let avgMotion = recentMotions.isEmpty ? 0.0 : recentMotions.reduce(0.0, +) / Double(recentMotions.count)
        
        // Classification basée sur les cycles circadiens de 90 minutes et les capteurs
        let cycleProgress = elapsedMinutes.truncatingRemainder(dividingBy: 90.0) // Position dans le cycle de 90m
        var evaluatedStage: SleepStage = .light
        
        if elapsedMinutes < 15.0 {
            // Période d'endormissement (0 à 15 min)
            if avgMotion > 0.08 || avgSound > 48.0 {
                evaluatedStage = .awake
            } else {
                evaluatedStage = .light
            }
        } else if avgMotion > 0.15 || avgSound > 58.0 {
            // Fort mouvement ou grand bruit nocturne -> micro-réveil
            evaluatedStage = .awake
        } else if avgMotion > 0.05 || avgSound > 46.0 {
            // Petits mouvements / agitation -> Sommeil léger
            evaluatedStage = .light
        } else {
            // Calme physique et sonore : alternance selon le cycle naturel de 90 minutes
            // 0 - 25m : Léger descendant
            // 25 - 65m : Sommeil Profond
            // 65 - 85m : Sommeil Paradoxal (REM)
            // 85 - 90m : Retour en Léger
            if cycleProgress >= 25.0 && cycleProgress < 65.0 {
                evaluatedStage = .deep
            } else if cycleProgress >= 65.0 && cycleProgress < 85.0 {
                evaluatedStage = .rem
            } else {
                evaluatedStage = .light
            }
        }
        
        self.currentStage = evaluatedStage
        
        let epoch = SleepStageEpoch(
            timestamp: date,
            stage: evaluatedStage,
            soundLevelDB: avgSound,
            motionIntensity: avgMotion
        )
        self.recordedEpochs.append(epoch)
    }
    
    // MARK: - Vérification du Réveil Intelligent (Smart Alarm)
    
    /// Vérifie si une alarme programmée avec Réveil Intelligent doit sonner maintenant
    /// Déclenche si l'heure actuelle se trouve dans la fenêtre (ex: 30 min) et que l'utilisateur est en sommeil léger ou éveillé
    public func checkSmartAlarmTrigger(alarms: [Alarm], at date: Date) -> Alarm? {
        guard isAnalyzing, !smartAlarmTriggered else { return nil }
        
        let calendar = Calendar.current
        
        for alarm in alarms where alarm.isEnabled && alarm.isSmartAlarmEnabled {
            guard let nextDate = alarm.nextTriggerDate() else { continue }
            
            let windowSeconds = Double(alarm.smartAlarmWindowMinutes) * 60.0
            let windowStart = nextDate.addingTimeInterval(-windowSeconds)
            
            // Si on est dans la fenêtre temporelle
            if date >= windowStart && date <= nextDate {
                // Et que l'utilisateur est dans une phase propice au réveil (léger ou éveillé)
                if currentStage == .light || currentStage == .awake {
                    self.smartAlarmTriggered = true
                    return alarm
                }
            }
        }
        return nil
    }
    
    // MARK: - Clôture et Calcul des Résultats Finaux
    
    public func finishAnalysis() -> (
        stages: [SleepStageEpoch],
        snoreMinutes: Int,
        snoreEpisodes: Int,
        averageDB: Double,
        sleepScore: Int
    ) {
        // Arrêt des capteurs
        analysisTimer?.invalidate()
        analysisTimer = nil
        
        if let recorder = audioRecorder, recorder.isRecording {
            recorder.stop()
        }
        audioRecorder = nil
        motionManager.stopAccelerometerUpdates()
        
        // Évaluation finale de la dernière époque
        let now = Date()
        evaluateAndRecordEpoch(at: now)
        
        let finalEpochs = self.recordedEpochs
        let finalSnoreMin = self.currentSnoreMinutes
        let finalSnoreEpisodes = self.snoreEpisodes
        
        // Moyenne sonore globale
        let avgDB = soundSamples.isEmpty ? 32.0 : (soundSamples.reduce(0.0, +) / Double(soundSamples.count))
        
        // Calcul du Score de Sommeil Scientifique (0 à 100)
        let finalScore = calculateSleepScore(
            epochs: finalEpochs,
            snoreMinutes: finalSnoreMin,
            averageDB: avgDB
        )
        
        self.isAnalyzing = false
        self.sessionStartTime = nil
        
        return (finalEpochs, finalSnoreMin, finalSnoreEpisodes, avgDB, finalScore)
    }
    
    public func cancelAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = nil
        if let recorder = audioRecorder, recorder.isRecording {
            recorder.stop()
        }
        audioRecorder = nil
        motionManager.stopAccelerometerUpdates()
        self.isAnalyzing = false
        self.sessionStartTime = nil
        self.recordedEpochs = []
    }
    
    // MARK: - Algorithme de Calcul du Score de Sommeil
    
    private func calculateSleepScore(epochs: [SleepStageEpoch], snoreMinutes: Int, averageDB: Double) -> Int {
        guard !epochs.isEmpty else { return 80 }
        
        var score: Double = 100.0
        
        let deepCount = epochs.filter { $0.stage == .deep }.count
        let awakeCount = epochs.filter { $0.stage == .awake }.count
        let totalCount = epochs.count
        
        let deepRatio = Double(deepCount) / Double(totalCount)
        let awakeRatio = Double(awakeCount) / Double(totalCount)
        
        // 1. Proportion de sommeil profond (idéale: 18% à 25%)
        if deepRatio < 0.10 {
            score -= 15.0
        } else if deepRatio < 0.15 {
            score -= 8.0
        }
        
        // 2. Micro-réveils fréquents
        if awakeRatio > 0.15 {
            score -= 15.0
        } else if awakeRatio > 0.08 {
            score -= 8.0
        }
        
        // 3. Ronflements excessifs
        if snoreMinutes > 40 {
            score -= 12.0
        } else if snoreMinutes > 20 {
            score -= 6.0
        }
        
        // 4. Bruits ambiants perturbateurs
        if averageDB > 55.0 {
            score -= 10.0
        } else if averageDB > 45.0 {
            score -= 5.0
        }
        
        return max(30, min(100, Int(score)))
    }
}
