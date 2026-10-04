import Foundation
import SwiftData

@Model
final class GroupMemberEntity {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var name: String
    var email: String
    var profileImage: Data?
    var roleRaw: String
    var joinedAt: Date
    var group: GroupEntity?

    init(
        id: UUID,
        userId: UUID,
        name: String,
        email: String,
        profileImage: Data?,
        roleRaw: String,
        joinedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.email = email
        self.profileImage = profileImage
        self.roleRaw = roleRaw
        self.joinedAt = joinedAt
    }
}
