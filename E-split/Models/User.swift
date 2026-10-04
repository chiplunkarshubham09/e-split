import Foundation

struct AppUser: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var email: String
    var profileImage: Data?
}
