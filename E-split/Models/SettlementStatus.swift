import Foundation

enum SettlementStatus: String, Codable, CaseIterable, Hashable {
    case pending
    case paid

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .paid: return "Paid"
        }
    }
}
