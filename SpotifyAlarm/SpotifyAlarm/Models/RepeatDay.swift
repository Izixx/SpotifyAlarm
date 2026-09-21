import Foundation

/// Représente un jour de répétition pour une alarme.
/// Les valeurs brutes correspondent aux conventions de `Calendar.Component.weekday` (1 = Dimanche, 7 = Samedi).
public enum RepeatDay: Int, CaseIterable, Codable, Identifiable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    public var id: Int { rawValue }
    
    public static func < (lhs: RepeatDay, rhs: RepeatDay) -> Bool {
        // Tri naturel européen (Lundi en premier, Dimanche en dernier)
        let lhsOrder = lhs == .sunday ? 7 : lhs.rawValue - 1
        let rhsOrder = rhs == .sunday ? 7 : rhs.rawValue - 1
        return lhsOrder < rhsOrder
    }
    
    /// Abréviation en français (3 lettres)
    public var shortName: String {
        switch self {
        case .monday: return "Lun"
        case .tuesday: return "Mar"
        case .wednesday: return "Mer"
        case .thursday: return "Jeu"
        case .friday: return "Ven"
        case .saturday: return "Sam"
        case .sunday: return "Dim"
        }
    }
    
    /// Nom complet en français
    public var fullName: String {
        switch self {
        case .monday: return "Lundi"
        case .tuesday: return "Mardi"
        case .wednesday: return "Mercredi"
        case .thursday: return "Jeudi"
        case .friday: return "Vendredi"
        case .saturday: return "Samedi"
        case .sunday: return "Dimanche"
        }
    }
    
    /// Liste ordonnée de la semaine pour l'affichage UI (Lundi à Dimanche)
    public static var orderedWeekdays: [RepeatDay] {
        return [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
    
    /// Résumé textuel d'un ensemble de jours (ex: "Tous les jours", "En semaine", "Le week-end")
    public static func summary(for days: Set<RepeatDay>) -> String {
        if days.isEmpty {
            return "Une seule fois"
        }
        if days.count == 7 {
            return "Tous les jours"
        }
        
        let weekdays: Set<RepeatDay> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let weekend: Set<RepeatDay> = [.saturday, .sunday]
        
        if days == weekdays {
            return "En semaine (Lun - Ven)"
        }
        if days == weekend {
            return "Le week-end (Sam - Dim)"
        }
        
        return days.sorted().map { $0.shortName }.joined(separator: " ")
    }
}
