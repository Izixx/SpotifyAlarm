import Foundation
import Combine

@MainActor
public final class AlarmEditViewModel: ObservableObject {
    
    public let alarmId: UUID
    public let isNew: Bool
    
    @Published public var title: String
    @Published public var time: Date
    @Published public var repeatDays: Set<RepeatDay>
    @Published public var spotifyItem: SpotifyTrackItem?
    @Published public var customAudioFileName: String?
    @Published public var customAudioTitle: String?
    @Published public var vibrateOnBeat: Bool
    @Published public var volume: Float
    @Published public var isEnabled: Bool
    
    @Published public var isSpotifyPickerPresented: Bool = false
    @Published public var isCustomAudioPickerPresented: Bool = false
    
    private let alarmService = AlarmService.shared
    
    public init(alarm: Alarm? = nil) {
        if let alarm = alarm {
            self.alarmId = alarm.id
            self.isNew = false
            self.title = alarm.title
            self.time = alarm.time
            self.repeatDays = alarm.repeatDays
            self.spotifyItem = alarm.spotifyItem
            self.customAudioFileName = alarm.customAudioFileName
            self.customAudioTitle = alarm.customAudioTitle
            self.vibrateOnBeat = alarm.vibrateOnBeat
            self.volume = alarm.volume
            self.isEnabled = alarm.isEnabled
        } else {
            self.alarmId = UUID()
            self.isNew = true
            self.title = "Alarme"
            
            // Heure par défaut : 07:00
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = 7
            comps.minute = 0
            self.time = Calendar.current.date(from: comps) ?? Date()
            
            self.repeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
            self.spotifyItem = nil
            self.customAudioFileName = nil
            self.customAudioTitle = nil
            self.vibrateOnBeat = true
            self.volume = 0.8
            self.isEnabled = true
        }
    }
    
    public func toggleDay(_ day: RepeatDay) {
        if repeatDays.contains(day) {
            repeatDays.remove(day)
        } else {
            repeatDays.insert(day)
        }
    }
    
    public func selectSpotifyItem(_ item: SpotifyTrackItem?) {
        self.spotifyItem = item
        self.customAudioFileName = nil
        self.customAudioTitle = nil
    }
    
    public func selectCustomAudio(_ file: CustomAudioFile?) {
        self.customAudioFileName = file?.fileName
        self.customAudioTitle = file?.title
        self.spotifyItem = nil
    }
    
    public func selectDefaultSound() {
        self.spotifyItem = nil
        self.customAudioFileName = nil
        self.customAudioTitle = nil
    }
    
    public func save() {
        let alarm = Alarm(
            id: alarmId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Alarme" : title,
            time: time,
            repeatDays: repeatDays,
            spotifyItem: spotifyItem,
            customAudioFileName: customAudioFileName,
            customAudioTitle: customAudioTitle,
            vibrateOnBeat: vibrateOnBeat,
            volume: volume,
            isEnabled: isEnabled
        )
        alarmService.saveAlarm(alarm)
    }
}
