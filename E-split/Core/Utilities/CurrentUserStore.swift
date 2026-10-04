import Foundation

struct CurrentUser: Equatable, Hashable, Codable {
    var id: UUID
    var name: String
    var email: String
}
