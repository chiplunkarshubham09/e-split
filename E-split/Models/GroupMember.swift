import Foundation

struct GroupMember: Identifiable, Hashable, Codable {
    var id: UUID
    var userId: UUID
    var groupId: UUID
    var name: String
    var email: String
    var profileImage: Data?
    var role: MemberRole
    var joinedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        groupId: UUID,
        name: String,
        email: String = "",
        profileImage: Data? = nil,
        role: MemberRole,
        joinedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.groupId = groupId
        self.name = name
        self.email = email
        self.profileImage = profileImage
        self.role = role
        self.joinedAt = joinedAt
    }
}
