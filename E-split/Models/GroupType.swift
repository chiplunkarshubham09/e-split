import Foundation

enum GroupType: String, Codable, CaseIterable, Identifiable, Hashable {
    case trip
    case home
    case friends
    case couple
    case office
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trip: return "Trip"
        case .home: return "Home"
        case .friends: return "Friends"
        case .couple: return "Couple"
        case .office: return "Office"
        case .custom: return "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .trip: return "airplane"
        case .home: return "house.fill"
        case .friends: return "person.2.fill"
        case .couple: return "heart.fill"
        case .office: return "briefcase.fill"
        case .custom: return "square.grid.2x2.fill"
        }
    }
}
