import SwiftUI

/// Ligne d'affichage pour une alarme dans la liste principale
public struct AlarmRowView: View {
    public let alarm: Alarm
    public let onToggle: () -> Void
    public let onEdit: () -> Void
    
    public init(alarm: Alarm, onToggle: @escaping () -> Void, onEdit: @escaping () -> Void) {
        self.alarm = alarm
        self.onToggle = onToggle
        self.onEdit = onEdit
    }
    
    public var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    // Heure principale (ex: 07:00)
                    Text(alarm.formattedTime)
                        .font(.system(size: 44, weight: .light, design: .rounded))
                        .foregroundColor(alarm.isEnabled ? .white : .gray.opacity(0.6))
                    
                    // Jours de répétition & Titre
                    HStack(spacing: 8) {
                        Text(alarm.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(alarm.isEnabled ? .white : .gray.opacity(0.7))
                        
                        Text("•")
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(alarm.repeatDescription)
                            .font(.system(size: 13))
                            .foregroundColor(alarm.isEnabled ? .gray : .gray.opacity(0.5))
                    }
                    
                    // Morceau Spotify
                    HStack(spacing: 6) {
                        Image(systemName: alarm.spotifyItem != nil ? "music.note" : "bell.fill")
                            .font(.system(size: 12))
                            .foregroundColor(alarm.isEnabled ? Color(red: 0.114, green: 0.725, blue: 0.329) : .gray)
                        
                        Text(alarm.musicDescription)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(alarm.isEnabled ? Color(red: 0.114, green: 0.725, blue: 0.329) : .gray.opacity(0.7))
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
                
                Spacer()
                
                // Interrupteur ON / OFF
                Toggle("", isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.114, green: 0.725, blue: 0.329)))
            }
            .padding(16)
            .background(Color(white: 0.11))
            .cornerRadius(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
