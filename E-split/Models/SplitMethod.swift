import Foundation

enum SplitMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case equal
    case exactAmount
    case percentage
    case shares

    var id: String { rawValue }

    var title: String {
        switch self {
        case .equal: return "Equal"
        case .exactAmount: return "Exact amounts"
        case .percentage: return "Percentage"
        case .shares: return "Shares"
        }
    }

    var subtitle: String {
        switch self {
        case .equal: return "Split the total evenly"
        case .exactAmount: return "Enter each person’s amount"
        case .percentage: return "Split by percentage"
        case .shares: return "Split by share count"
        }
    }
}
