import Foundation
import SwiftUI

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case food
    case hotel
    case transport
    case entertainment
    case shopping
    case medical
    case rent
    case utilities
    case travel
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return "Food"
        case .hotel: return "Hotel"
        case .transport: return "Transport"
        case .entertainment: return "Entertainment"
        case .shopping: return "Shopping"
        case .medical: return "Medical"
        case .rent: return "Rent"
        case .utilities: return "Utilities"
        case .travel: return "Travel"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .food: return "fork.knife"
        case .hotel: return "bed.double.fill"
        case .transport: return "car.fill"
        case .entertainment: return "theatermasks.fill"
        case .shopping: return "bag.fill"
        case .medical: return "cross.case.fill"
        case .rent: return "building.2.fill"
        case .utilities: return "bolt.fill"
        case .travel: return "airplane"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .food, .travel, .transport:
            return AppTheme.primary
        case .hotel, .rent, .utilities:
            return Color(hex: 0x2B4F9B)
        case .entertainment, .shopping, .medical, .other:
            return AppTheme.secondary
        }
    }
}
