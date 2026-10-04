import Foundation

struct ExpenseGroup: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var description: String
    var currency: String
    var type: GroupType?
    var createdBy: UUID
    var createdAt: Date
    var isArchived: Bool
    var inviteCode: String
    var members: [GroupMember]

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        currency: String = AppStrings.defaultCurrencyCode,
        type: GroupType? = nil,
        createdBy: UUID,
        createdAt: Date = .now,
        isArchived: Bool = false,
        inviteCode: String = InviteCode.generate(),
        members: [GroupMember] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.currency = currency
        self.type = type
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.inviteCode = inviteCode
        self.members = members
    }

    func member(for userId: UUID) -> GroupMember? {
        members.first { $0.userId == userId }
    }

    func displayName(for userId: UUID, currentUserID: UUID) -> String {
        if userId == currentUserID {
            return AppStrings.you
        }
        return member(for: userId)?.name ?? "Unknown"
    }
}
