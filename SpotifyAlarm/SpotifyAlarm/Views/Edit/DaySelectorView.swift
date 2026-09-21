import SwiftUI

/// Sélecteur interactif des jours de répétition (Lundi à Dimanche)
public struct DaySelectorView: View {
    @Binding public var selectedDays: Set<RepeatDay>
    
    public init(selectedDays: Binding<Set<RepeatDay>>) {
        self._selectedDays = selectedDays
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Chips pour les 7 jours de la semaine
            HStack(spacing: 8) {
                ForEach(RepeatDay.orderedWeekdays) { day in
                    let isSelected = selectedDays.contains(day)
                    Button(action: {
                        toggle(day)
                    }) {
                        Text(day.shortName)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(
                                isSelected ?
                                Color(red: 0.114, green: 0.725, blue: 0.329) :
                                Color(white: 0.18)
                            )
                            .foregroundColor(isSelected ? .black : .white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Raccourcis rapides : En semaine / Week-end / Tous les jours
            HStack(spacing: 12) {
                quickSelectButton(title: "En semaine", days: [.monday, .tuesday, .wednesday, .thursday, .friday])
                quickSelectButton(title: "Week-end", days: [.saturday, .sunday])
                quickSelectButton(title: "Tous les jours", days: Set(RepeatDay.allCases))
            }
            .font(.caption)
        }
    }
    
    private func toggle(_ day: RepeatDay) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
    
    private func quickSelectButton(title: String, days: Set<RepeatDay>) -> some View {
        let isMatching = selectedDays == days
        return Button(action: {
            if isMatching {
                selectedDays.removeAll()
            } else {
                selectedDays = days
            }
        }) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isMatching ? Color(red: 0.114, green: 0.725, blue: 0.329).opacity(0.2) : Color(white: 0.14))
                .foregroundColor(isMatching ? Color(red: 0.114, green: 0.725, blue: 0.329) : .gray)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
