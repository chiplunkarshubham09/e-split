import Foundation
import SwiftData

@Model
final class UserAccountEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var email: String
    var name: String
    var passwordHash: Data
    var passwordSalt: Data
    var createdAt: Date

    init(
        id: UUID,
        email: String,
        name: String,
        passwordHash: Data,
        passwordSalt: Data,
        createdAt: Date
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.passwordHash = passwordHash
        self.passwordSalt = passwordSalt
        self.createdAt = createdAt
    }
}
