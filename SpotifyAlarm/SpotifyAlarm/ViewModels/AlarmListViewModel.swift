import Foundation
import Combine
import SwiftUI

@MainActor
public final class AlarmListViewModel: ObservableObject {
    
    @Published public var alarms: [Alarm] = []
    @Published public var isCreatingAlarm: Bool = false
    @Published public var editingAlarm: Alarm? = nil
    @Published public var isSettingsPresented: Bool = false
    @Published public var isNightstandPresented: Bool = false
    
    @Published public var isTestingAlarm: Bool = false
    @Published public var testAlertMessage: String? = nil
    @Published public var showTestAlert: Bool = false
    
    private let alarmService = AlarmService.shared
    private let notificationService = NotificationService.shared
    private let audioPlayerService = AudioPlayerService.shared
    private let authService = SpotifyAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        // Observer les alarmes du service
        alarmService.$alarms
            .assign(to: \.alarms, on: self)
            .store(in: &cancellables)
    }
    
    public var isSpotifyConnected: Bool {
        return authService.isAuthenticated
    }
    
    public var currentUserName: String? {
        return authService.currentUser?.displayName
    }
    
    public func toggleAlarm(_ alarm: Alarm) {
        alarmService.toggleAlarm(alarm)
    }
    
    public func deleteAlarm(at offsets: IndexSet) {
        alarmService.deleteAlarms(at: offsets)
    }
    
    public func deleteAlarm(id: UUID) {
        alarmService.deleteAlarm(id: id)
    }
    
    // MARK: - Test d'Alarme
    
    /// Test immédiat : planifie la notification dans 3s et teste l'audio
    public func runAlarmTest() {
        isTestingAlarm = true
        
        Task {
            // 1. Demande de permission si pas encore accordée
            let granted = await notificationService.requestAuthorization()
            guard granted else {
                testAlertMessage = "Les notifications sont désactivées. Veuillez les autoriser dans Réglages > Spotify Alarm pour que l'alarme sonne."
                showTestAlert = true
                isTestingAlarm = false
                return
            }
            
            // 2. Récupérer un morceau de test (première alarme avec Spotify ou nil)
            let testItem = alarms.first(where: { $0.spotifyItem != nil })?.spotifyItem
            
            // 3. Programmer la notification locale de test
            notificationService.scheduleTestNotification(in: 3.0, spotifyItem: testItem) { [weak self] success in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isTestingAlarm = false
                    
                    if success {
                        // Joue un bref extrait du son d'alarme pour valider le moteur audio
                        self.audioPlayerService.playAlarmSound(targetVolume: 0.7, fadeInDuration: 0.5)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            self.audioPlayerService.stopAlarmSound()
                        }
                        
                        let spotifyStatus = self.isSpotifyConnected
                            ? "✅ Spotify connecté (Compte: \(self.currentUserName ?? "OK"))"
                            : "⚠️ Spotify non connecté (Sonnerie carillon par défaut)"
                        
                        self.testAlertMessage = """
                        🔔 Test d'alarme lancé !
                        
                        • Notification programmée dans 3 secondes.
                        • Test audio en cours.
                        • \(spotifyStatus)
                        
                        Verrouillez votre écran ou mettez l'app en arrière-plan pour voir la bannière apparaître avec l'action 'Lancer Spotify'.
                        """
                        self.showTestAlert = true
                    } else {
                        self.testAlertMessage = "Impossible de programmer la notification de test."
                        self.showTestAlert = true
                    }
                }
            }
        }
    }
}
