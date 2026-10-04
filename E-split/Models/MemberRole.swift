import Foundation

enum MemberRole: String, Codable, CaseIterable, Hashable {
    case admin
    case member

    var title: String {
        switch self {
        case .admin: return "Admin"
        case .member: return "Member"
        }
    }
}
