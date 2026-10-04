import Foundation

protocol GroupRepositoryProtocol {
    func fetchGroups(includeArchived: Bool) async throws -> [ExpenseGroup]
    func fetchGroup(id: UUID) async throws -> ExpenseGroup?
    func fetchGroup(inviteCode: String) async throws -> ExpenseGroup?
    func createGroup(_ group: ExpenseGroup) async throws
    func updateGroup(_ group: ExpenseGroup) async throws
    func deleteGroup(id: UUID) async throws
    func addMember(_ member: GroupMember) async throws
    func updateMember(_ member: GroupMember) async throws
    func removeMember(id: UUID, groupId: UUID) async throws
    func joinGroup(inviteCode: String, user: CurrentUser) async throws -> ExpenseGroup
}

final class GroupRepository: GroupRepositoryProtocol {
    private let local: LocalExpenseDataSource
    private let remote: RemoteBackend?

    init(local: LocalExpenseDataSource, remote: RemoteBackend? = nil) {
        self.local = local
        self.remote = remote
    }

    func fetchGroups(includeArchived: Bool = false) async throws -> [ExpenseGroup] {
        if let remote {
            do {
                let groups = try await remote.fetchGroups()
                for group in groups {
                    try? local.cacheGroup(group)
                }
                return includeArchived ? groups : groups.filter { !$0.isArchived }
            } catch {
                return try local.fetchGroups(includeArchived: includeArchived)
            }
        }
        return try local.fetchGroups(includeArchived: includeArchived)
    }

    func fetchGroup(id: UUID) async throws -> ExpenseGroup? {
        if let remote, let group = try? await remote.fetchGroup(id: id) {
            try? local.cacheGroup(group)
            return group
        }
        return try local.fetchGroup(id: id)
    }

    func fetchGroup(inviteCode: String) async throws -> ExpenseGroup? {
        if let remote, let group = try? await remote.fetchGroup(inviteCode: inviteCode) {
            return group
        }
        return try local.fetchGroup(inviteCode: inviteCode)
    }

    func createGroup(_ group: ExpenseGroup) async throws {
        if let remote {
            try await remote.createGroup(group)
        }
        try local.saveGroup(group)
    }

    func updateGroup(_ group: ExpenseGroup) async throws {
        if let remote {
            try await remote.updateGroup(group)
        }
        try local.saveGroup(group)
    }

    func deleteGroup(id: UUID) async throws {
        if let remote {
            try await remote.deleteGroup(id: id)
        }
        try local.deleteGroup(id: id)
    }

    func addMember(_ member: GroupMember) async throws {
        if let remote {
            try await remote.addMember(member)
            if let group = try await remote.fetchGroup(id: member.groupId) {
                try local.cacheGroup(group)
                return
            }
        }
        try local.addMember(member)
    }

    func updateMember(_ member: GroupMember) async throws {
        if let remote {
            try await remote.updateMember(member)
        }
        try local.updateMember(member)
    }

    func removeMember(id: UUID, groupId: UUID) async throws {
        if let remote {
            try await remote.removeMember(id: id, groupId: groupId)
        }
        try local.deleteMember(id: id, groupId: groupId)
    }

    func joinGroup(inviteCode: String, user: CurrentUser) async throws -> ExpenseGroup {
        if let remote {
            let group = try await remote.joinGroup(inviteCode: inviteCode, user: user)
            try local.cacheGroup(group)
            return group
        }
        let code = InviteCode.normalized(inviteCode)
        guard !code.isEmpty, let group = try local.fetchGroup(inviteCode: code) else {
            throw AppError.invalidInvite
        }
        if group.member(for: user.id) == nil {
            try local.addMember(
                GroupMember(
                    userId: user.id,
                    groupId: group.id,
                    name: user.name,
                    email: user.email,
                    role: .member
                )
            )
        }
        guard let latest = try local.fetchGroup(id: group.id) else {
            throw AppError.groupNotFound
        }
        return latest
    }
}
