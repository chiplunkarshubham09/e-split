import Foundation
import SwiftData

protocol LocalExpenseDataSource {
    func fetchGroups(includeArchived: Bool) throws -> [ExpenseGroup]
    func fetchGroup(id: UUID) throws -> ExpenseGroup?
    func fetchGroup(inviteCode: String) throws -> ExpenseGroup?
    func saveGroup(_ group: ExpenseGroup) throws
    func cacheGroup(_ group: ExpenseGroup) throws
    func deleteGroup(id: UUID) throws

    func addMember(_ member: GroupMember) throws
    func updateMember(_ member: GroupMember) throws
    func deleteMember(id: UUID, groupId: UUID) throws

    func fetchExpenses(groupId: UUID) throws -> [Expense]
    func fetchExpense(id: UUID) throws -> Expense?
    func saveExpense(_ expense: Expense) throws
    func deleteExpense(id: UUID) throws

    func fetchSettlements(groupId: UUID) throws -> [Settlement]
    func saveSettlement(_ settlement: Settlement) throws
    func deleteSettlement(id: UUID) throws

    func fetchAccount(email: String) throws -> StoredAccount?
    func fetchAccount(id: UUID) throws -> StoredAccount?
    func saveAccount(_ account: StoredAccount) throws
}

struct StoredAccount: Equatable {
    var id: UUID
    var name: String
    var email: String
    var passwordHash: Data
    var passwordSalt: Data
    var createdAt: Date
}

final class SwiftDataLocalDataSource: LocalExpenseDataSource {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchGroups(includeArchived: Bool) throws -> [ExpenseGroup] {
        var descriptor = FetchDescriptor<GroupEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if !includeArchived {
            descriptor.predicate = #Predicate { !$0.isArchived }
        }
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func fetchGroup(id: UUID) throws -> ExpenseGroup? {
        try fetchGroupEntity(id: id)?.toDomain()
    }

    func fetchGroup(inviteCode: String) throws -> ExpenseGroup? {
        let code = InviteCode.normalized(inviteCode)
        let descriptor = FetchDescriptor<GroupEntity>(
            predicate: #Predicate { $0.inviteCode == code }
        )
        return try context.fetch(descriptor).first?.toDomain()
    }

    func saveGroup(_ group: ExpenseGroup) throws {
        if let existing = try fetchGroupEntity(id: group.id) {
            existing.name = group.name
            existing.groupDescription = group.description
            existing.currency = group.currency
            existing.typeRaw = group.type?.rawValue
            existing.isArchived = group.isArchived
            existing.inviteCode = group.inviteCode
            try syncMembers(group.members, onto: existing)
        } else {
            let entity = GroupEntity(
                id: group.id,
                name: group.name,
                groupDescription: group.description,
                currency: group.currency,
                typeRaw: group.type?.rawValue,
                createdBy: group.createdBy,
                createdAt: group.createdAt,
                isArchived: group.isArchived,
                inviteCode: group.inviteCode
            )
            context.insert(entity)
            for member in group.members {
                let memberEntity = member.toEntity()
                memberEntity.group = entity
                context.insert(memberEntity)
            }
        }
        try context.save()
    }

    func cacheGroup(_ group: ExpenseGroup) throws {
        try saveGroup(group)
    }

    func deleteGroup(id: UUID) throws {
        guard let entity = try fetchGroupEntity(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    func addMember(_ member: GroupMember) throws {
        guard let group = try fetchGroupEntity(id: member.groupId) else {
            throw AppError.groupNotFound
        }
        if group.members.contains(where: { $0.userId == member.userId }) {
            return
        }
        let entity = member.toEntity()
        entity.group = group
        context.insert(entity)
        try context.save()
    }

    func updateMember(_ member: GroupMember) throws {
        guard let entity = try fetchMemberEntity(id: member.id) else {
            throw AppError.memberNotFound
        }
        entity.name = member.name
        entity.email = member.email
        entity.profileImage = member.profileImage
        entity.roleRaw = member.role.rawValue
        try context.save()
    }

    func deleteMember(id: UUID, groupId: UUID) throws {
        guard let entity = try fetchMemberEntity(id: id), entity.group?.id == groupId else {
            throw AppError.memberNotFound
        }
        context.delete(entity)
        try context.save()
    }

    func fetchExpenses(groupId: UUID) throws -> [Expense] {
        let descriptor = FetchDescriptor<ExpenseEntity>(
            predicate: #Predicate { $0.groupId == groupId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func fetchExpense(id: UUID) throws -> Expense? {
        try fetchExpenseEntity(id: id)?.toDomain()
    }

    func saveExpense(_ expense: Expense) throws {
        guard let group = try fetchGroupEntity(id: expense.groupId) else {
            throw AppError.groupNotFound
        }

        let entity: ExpenseEntity
        if let existing = try fetchExpenseEntity(id: expense.id) {
            existing.splits.forEach { context.delete($0) }
            entity = existing
            entity.title = expense.title
            entity.amount = expense.amount
            entity.categoryRaw = expense.category.rawValue
            entity.paidBy = expense.paidBy
            entity.notes = expense.notes
            entity.splitMethodRaw = expense.splitMethod.rawValue
            entity.createdAt = expense.createdAt
        } else {
            entity = ExpenseEntity(
                id: expense.id,
                groupId: expense.groupId,
                title: expense.title,
                amount: expense.amount,
                categoryRaw: expense.category.rawValue,
                paidBy: expense.paidBy,
                createdBy: expense.createdBy,
                createdAt: expense.createdAt,
                notes: expense.notes,
                splitMethodRaw: expense.splitMethod.rawValue
            )
            entity.group = group
            context.insert(entity)
        }

        for split in expense.splits {
            let splitEntity = split.toEntity()
            splitEntity.expense = entity
            context.insert(splitEntity)
        }
        try context.save()
    }

    func deleteExpense(id: UUID) throws {
        guard let entity = try fetchExpenseEntity(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    func fetchSettlements(groupId: UUID) throws -> [Settlement] {
        let descriptor = FetchDescriptor<SettlementEntity>(
            predicate: #Predicate { $0.groupId == groupId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func saveSettlement(_ settlement: Settlement) throws {
        guard let group = try fetchGroupEntity(id: settlement.groupId) else {
            throw AppError.groupNotFound
        }
        if let existing = try fetchSettlementEntity(id: settlement.id) {
            existing.fromUser = settlement.fromUser
            existing.toUser = settlement.toUser
            existing.amount = settlement.amount
            existing.statusRaw = settlement.status.rawValue
            existing.settledAt = settlement.settledAt
        } else {
            let entity = settlement.toEntity()
            entity.group = group
            context.insert(entity)
        }
        try context.save()
    }

    func deleteSettlement(id: UUID) throws {
        guard let entity = try fetchSettlementEntity(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    func fetchAccount(email: String) throws -> StoredAccount? {
        let normalized = EmailValidator.normalized(email)
        let descriptor = FetchDescriptor<UserAccountEntity>(
            predicate: #Predicate { $0.email == normalized }
        )
        return try context.fetch(descriptor).first?.toStored()
    }

    func fetchAccount(id: UUID) throws -> StoredAccount? {
        let descriptor = FetchDescriptor<UserAccountEntity>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first?.toStored()
    }

    func saveAccount(_ account: StoredAccount) throws {
        if let existing = try fetchAccountEntity(id: account.id) {
            existing.name = account.name
            existing.email = account.email
            existing.passwordHash = account.passwordHash
            existing.passwordSalt = account.passwordSalt
        } else {
            context.insert(
                UserAccountEntity(
                    id: account.id,
                    email: account.email,
                    name: account.name,
                    passwordHash: account.passwordHash,
                    passwordSalt: account.passwordSalt,
                    createdAt: account.createdAt
                )
            )
        }
        try context.save()
    }

    private func fetchAccountEntity(id: UUID) throws -> UserAccountEntity? {
        let descriptor = FetchDescriptor<UserAccountEntity>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    private func syncMembers(_ members: [GroupMember], onto group: GroupEntity) throws {
        let incomingUserIDs = Set(members.map(\.userId))
        for existing in group.members where !incomingUserIDs.contains(existing.userId) {
            context.delete(existing)
        }
        for member in members {
            if let row = group.members.first(where: { $0.userId == member.userId }) {
                row.name = member.name
                row.email = member.email
                row.roleRaw = member.role.rawValue
            } else {
                let entity = member.toEntity()
                entity.group = group
                context.insert(entity)
            }
        }
    }

    private func fetchGroupEntity(id: UUID) throws -> GroupEntity? {
        let descriptor = FetchDescriptor<GroupEntity>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    private func fetchMemberEntity(id: UUID) throws -> GroupMemberEntity? {
        let descriptor = FetchDescriptor<GroupMemberEntity>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    private func fetchExpenseEntity(id: UUID) throws -> ExpenseEntity? {
        let descriptor = FetchDescriptor<ExpenseEntity>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    private func fetchSettlementEntity(id: UUID) throws -> SettlementEntity? {
        let descriptor = FetchDescriptor<SettlementEntity>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }
}

private extension GroupEntity {
    func toDomain() -> ExpenseGroup {
        ExpenseGroup(
            id: id,
            name: name,
            description: groupDescription,
            currency: currency,
            type: typeRaw.flatMap(GroupType.init(rawValue:)),
            createdBy: createdBy,
            createdAt: createdAt,
            isArchived: isArchived,
            inviteCode: inviteCode,
            members: members
                .map { $0.toDomain(groupId: id) }
                .sorted { $0.joinedAt < $1.joinedAt }
        )
    }
}

private extension GroupMemberEntity {
    func toDomain(groupId: UUID) -> GroupMember {
        GroupMember(
            id: id,
            userId: userId,
            groupId: groupId,
            name: name,
            email: email,
            profileImage: profileImage,
            role: MemberRole(rawValue: roleRaw) ?? .member,
            joinedAt: joinedAt
        )
    }
}

private extension GroupMember {
    func toEntity() -> GroupMemberEntity {
        GroupMemberEntity(
            id: id,
            userId: userId,
            name: name,
            email: email,
            profileImage: profileImage,
            roleRaw: role.rawValue,
            joinedAt: joinedAt
        )
    }
}

private extension ExpenseEntity {
    func toDomain() -> Expense {
        Expense(
            id: id,
            groupId: groupId,
            title: title,
            amount: amount,
            category: ExpenseCategory(rawValue: categoryRaw) ?? .other,
            paidBy: paidBy,
            createdBy: createdBy,
            createdAt: createdAt,
            notes: notes,
            splitMethod: SplitMethod(rawValue: splitMethodRaw) ?? .equal,
            splits: splits.map { $0.toDomain() }
        )
    }
}

private extension ExpenseSplitEntity {
    func toDomain() -> ExpenseSplit {
        ExpenseSplit(
            id: id,
            expenseId: expenseId,
            userId: userId,
            amount: amount,
            percentage: percentage,
            shares: shares
        )
    }
}

private extension ExpenseSplit {
    func toEntity() -> ExpenseSplitEntity {
        ExpenseSplitEntity(
            id: id,
            expenseId: expenseId,
            userId: userId,
            amount: amount,
            percentage: percentage,
            shares: shares
        )
    }
}

private extension SettlementEntity {
    func toDomain() -> Settlement {
        Settlement(
            id: id,
            groupId: groupId,
            fromUser: fromUser,
            toUser: toUser,
            amount: amount,
            status: SettlementStatus(rawValue: statusRaw) ?? .pending,
            createdAt: createdAt,
            settledAt: settledAt
        )
    }
}

private extension Settlement {
    func toEntity() -> SettlementEntity {
        SettlementEntity(
            id: id,
            groupId: groupId,
            fromUser: fromUser,
            toUser: toUser,
            amount: amount,
            statusRaw: status.rawValue,
            createdAt: createdAt,
            settledAt: settledAt
        )
    }
}

private extension UserAccountEntity {
    func toStored() -> StoredAccount {
        StoredAccount(
            id: id,
            name: name,
            email: email,
            passwordHash: passwordHash,
            passwordSalt: passwordSalt,
            createdAt: createdAt
        )
    }
}
