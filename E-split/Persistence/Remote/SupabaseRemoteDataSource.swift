import Foundation
import Supabase

final class SupabaseRemoteDataSource: RemoteBackend {
    private let client: SupabaseClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(url: URL, anonKey: String) {
        decoder = JSONDecoder.supabase
        encoder = JSONEncoder.supabase
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: .init(db: .init(encoder: encoder, decoder: decoder))
        )
    }

    func currentSessionUser() async -> CurrentUser? {
        do {
            let session = try await client.auth.session
            return await currentUser(from: session.user)
        } catch {
            return nil
        }
    }

    func register(name: String, email: String, password: String) async throws -> CurrentUser {
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["name": .string(name)]
            )
            let sessionUser: CurrentUser?
            if let session = response.session {
                sessionUser = await currentUser(from: session.user)
            } else {
                sessionUser = nil
            }
            return try await RemoteAuthSession.currentUser(
                fromSignupSession: sessionUser,
                login: { try await login(email: email, password: password) }
            )
        } catch {
            throw AuthRemoteErrorMapper.map(error)
        }
    }

    func login(email: String, password: String) async throws -> CurrentUser {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return await currentUser(from: session.user)
        } catch {
            throw AuthRemoteErrorMapper.map(error)
        }
    }

    func logout() async {
        try? await client.auth.signOut()
    }

    func updateProfileName(_ name: String, userId: UUID) async throws {
        try await client.from("profiles")
            .update(["name": name])
            .eq("id", value: userId)
            .execute()
    }

    func fetchGroups() async throws -> [ExpenseGroup] {
        let rows: [RemoteGroupRecord] = try await client.from("groups")
            .select("*, group_members(*)")
            .eq("is_archived", value: false)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func fetchGroup(id: UUID) async throws -> ExpenseGroup? {
        let rows: [RemoteGroupRecord] = try await client.from("groups")
            .select("*, group_members(*)")
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first?.toDomain()
    }

    func fetchGroup(inviteCode: String) async throws -> ExpenseGroup? {
        let params = InviteParams(p_code: InviteCode.normalized(inviteCode))
        let payload: RemoteGroupPreview? = try await client
            .rpc("preview_group", params: params)
            .execute()
            .value
        return payload?.toDomain()
    }

    func createGroup(_ group: ExpenseGroup) async throws {
        let session = try await client.auth.session
        try await ensureProfile(for: session.user)
        var payload = group
        if payload.createdBy != session.user.id {
            let previousID = payload.createdBy
            payload.createdBy = session.user.id
            payload.members = payload.members.map { member in
                var updated = member
                if updated.userId == previousID {
                    updated.userId = session.user.id
                }
                return updated
            }
        }
        try await client.from("groups")
            .insert(RemoteGroupWrite(from: payload))
            .execute()
        if !payload.members.isEmpty {
            try await client.from("group_members")
                .insert(payload.members.map(RemoteMemberWrite.init(from:)))
                .execute()
        }
    }

    func updateGroup(_ group: ExpenseGroup) async throws {
        try await client.from("groups")
            .update(RemoteGroupWrite(from: group))
            .eq("id", value: group.id)
            .execute()
    }

    func deleteGroup(id: UUID) async throws {
        try await client.from("groups")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func addMember(_ member: GroupMember) async throws {
        let email = EmailValidator.normalized(member.email)
        guard !email.isEmpty else { throw AppError.memberEmailRequired }
        struct Params: Encodable {
            let p_group_id: UUID
            let p_email: String
            let p_name: String
        }
        do {
            let _: UUID = try await client
                .rpc(
                    "add_member_by_email",
                    params: Params(p_group_id: member.groupId, p_email: email, p_name: member.name)
                )
                .execute()
                .value
        } catch {
            throw AuthRemoteErrorMapper.map(error)
        }
    }

    func updateMember(_ member: GroupMember) async throws {
        try await client.from("group_members")
            .update(RemoteMemberWrite(from: member))
            .eq("id", value: member.id)
            .execute()
    }

    func removeMember(id: UUID, groupId: UUID) async throws {
        try await client.from("group_members")
            .delete()
            .eq("id", value: id)
            .eq("group_id", value: groupId)
            .execute()
    }

    func joinGroup(inviteCode: String, user: CurrentUser) async throws -> ExpenseGroup {
        let params = InviteParams(p_code: InviteCode.normalized(inviteCode))
        let groupID: UUID = try await client
            .rpc("join_group", params: params)
            .execute()
            .value
        guard let group = try await fetchGroup(id: groupID) else {
            throw AppError.invalidInvite
        }
        _ = user
        return group
    }

    func fetchExpenses(groupId: UUID) async throws -> [Expense] {
        let rows: [RemoteExpenseRecord] = try await client.from("expenses")
            .select("*, expense_splits(*)")
            .eq("group_id", value: groupId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func saveExpense(_ expense: Expense) async throws {
        try await client.from("expenses")
            .upsert(RemoteExpenseWrite(from: expense))
            .execute()
        try await client.from("expense_splits")
            .delete()
            .eq("expense_id", value: expense.id)
            .execute()
        if !expense.splits.isEmpty {
            try await client.from("expense_splits")
                .insert(expense.splits.map(RemoteSplitWrite.init(from:)))
                .execute()
        }
    }

    func deleteExpense(id: UUID) async throws {
        try await client.from("expenses")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func fetchSettlements(groupId: UUID) async throws -> [Settlement] {
        let rows: [RemoteSettlementRecord] = try await client.from("settlements")
            .select()
            .eq("group_id", value: groupId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func saveSettlement(_ settlement: Settlement) async throws {
        try await client.from("settlements")
            .upsert(RemoteSettlementWrite(from: settlement))
            .execute()
    }

    private func currentUser(from user: User) async -> CurrentUser {
        let fallbackName = user.userMetadata["name"]?.stringValue
            ?? user.email?.split(separator: "@").first.map(String.init)
            ?? AppStrings.you
        let fallback = CurrentUser(id: user.id, name: fallbackName, email: user.email ?? "")
        do {
            return try await profile(for: user.id, fallback: fallback)
        } catch {
            return fallback
        }
    }

    private func ensureProfile(for user: User) async throws {
        let current = await currentUser(from: user)
        try await client.from("profiles")
            .upsert(RemoteProfile(id: user.id, name: current.name, email: current.email))
            .execute()
    }

    private func profile(for userID: UUID, fallback: CurrentUser) async throws -> CurrentUser {
        let rows: [RemoteProfile] = try await client.from("profiles")
            .select()
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        if let profile = rows.first {
            return CurrentUser(id: profile.id, name: profile.name, email: profile.email)
        }
        try? await client.from("profiles")
            .upsert(RemoteProfile(id: userID, name: fallback.name, email: fallback.email))
            .execute()
        return fallback
    }
}

private struct InviteParams: Encodable {
    let p_code: String
}

private struct RemoteProfile: Codable {
    var id: UUID
    var name: String
    var email: String
}

private struct RemoteGroupPreview: Decodable {
    var group: RemoteGroupRecord
    var members: [RemoteMemberRecord]?

    func toDomain() -> ExpenseGroup {
        var mapped = group
        mapped.groupMembers = members
        return mapped.toDomain()
    }
}

private struct RemoteGroupRecord: Decodable {
    var id: UUID
    var name: String
    var description: String
    var currency: String
    var type: String?
    var createdBy: UUID
    var createdAt: Date
    var isArchived: Bool
    var inviteCode: String
    var groupMembers: [RemoteMemberRecord]?

    func toDomain() -> ExpenseGroup {
        ExpenseGroup(
            id: id,
            name: name,
            description: description,
            currency: currency,
            type: type.flatMap(GroupType.init(rawValue:)),
            createdBy: createdBy,
            createdAt: createdAt,
            isArchived: isArchived,
            inviteCode: inviteCode,
            members: (groupMembers ?? []).map { $0.toDomain(groupId: id) }
        )
    }
}

private struct RemoteGroupWrite: Encodable {
    var id: UUID
    var name: String
    var description: String
    var currency: String
    var type: String?
    var createdBy: UUID
    var createdAt: Date
    var isArchived: Bool
    var inviteCode: String

    init(from group: ExpenseGroup) {
        id = group.id
        name = group.name
        description = group.description
        currency = group.currency
        type = group.type?.rawValue
        createdBy = group.createdBy
        createdAt = group.createdAt
        isArchived = group.isArchived
        inviteCode = group.inviteCode
    }
}

private struct RemoteMemberRecord: Decodable {
    var id: UUID
    var groupId: UUID
    var userId: UUID
    var name: String
    var email: String
    var role: String
    var joinedAt: Date

    func toDomain(groupId: UUID) -> GroupMember {
        GroupMember(
            id: id,
            userId: userId,
            groupId: groupId,
            name: name,
            email: email,
            role: MemberRole(rawValue: role) ?? .member,
            joinedAt: joinedAt
        )
    }
}

private struct RemoteMemberWrite: Encodable {
    var id: UUID
    var groupId: UUID
    var userId: UUID
    var name: String
    var email: String
    var role: String
    var joinedAt: Date

    init(from member: GroupMember) {
        id = member.id
        groupId = member.groupId
        userId = member.userId
        name = member.name
        email = member.email
        role = member.role.rawValue
        joinedAt = member.joinedAt
    }
}

private struct RemoteExpenseRecord: Decodable {
    var id: UUID
    var groupId: UUID
    var title: String
    var amount: Decimal
    var category: String
    var paidBy: UUID
    var createdBy: UUID
    var createdAt: Date
    var notes: String
    var splitMethod: String
    var expenseSplits: [RemoteSplitRecord]?

    func toDomain() -> Expense {
        Expense(
            id: id,
            groupId: groupId,
            title: title,
            amount: amount,
            category: ExpenseCategory(rawValue: category) ?? .other,
            paidBy: paidBy,
            createdBy: createdBy,
            createdAt: createdAt,
            notes: notes,
            splitMethod: SplitMethod(rawValue: splitMethod) ?? .equal,
            splits: (expenseSplits ?? []).map { $0.toDomain() }
        )
    }
}

private struct RemoteExpenseWrite: Encodable {
    var id: UUID
    var groupId: UUID
    var title: String
    var amount: Decimal
    var category: String
    var paidBy: UUID
    var createdBy: UUID
    var createdAt: Date
    var notes: String
    var splitMethod: String

    init(from expense: Expense) {
        id = expense.id
        groupId = expense.groupId
        title = expense.title
        amount = expense.amount
        category = expense.category.rawValue
        paidBy = expense.paidBy
        createdBy = expense.createdBy
        createdAt = expense.createdAt
        notes = expense.notes
        splitMethod = expense.splitMethod.rawValue
    }
}

private struct RemoteSplitRecord: Decodable {
    var id: UUID
    var expenseId: UUID
    var userId: UUID
    var amount: Decimal
    var percentage: Decimal?
    var shares: Decimal?

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

private struct RemoteSplitWrite: Encodable {
    var id: UUID
    var expenseId: UUID
    var userId: UUID
    var amount: Decimal
    var percentage: Decimal?
    var shares: Decimal?

    init(from split: ExpenseSplit) {
        id = split.id
        expenseId = split.expenseId
        userId = split.userId
        amount = split.amount
        percentage = split.percentage
        shares = split.shares
    }
}

private struct RemoteSettlementRecord: Decodable {
    var id: UUID
    var groupId: UUID
    var fromUser: UUID
    var toUser: UUID
    var amount: Decimal
    var status: String
    var createdAt: Date
    var settledAt: Date?

    func toDomain() -> Settlement {
        Settlement(
            id: id,
            groupId: groupId,
            fromUser: fromUser,
            toUser: toUser,
            amount: amount,
            status: SettlementStatus(rawValue: status) ?? .pending,
            createdAt: createdAt,
            settledAt: settledAt
        )
    }
}

private struct RemoteSettlementWrite: Encodable {
    var id: UUID
    var groupId: UUID
    var fromUser: UUID
    var toUser: UUID
    var amount: Decimal
    var status: String
    var createdAt: Date
    var settledAt: Date?

    init(from settlement: Settlement) {
        id = settlement.id
        groupId = settlement.groupId
        fromUser = settlement.fromUser
        toUser = settlement.toUser
        amount = settlement.amount
        status = settlement.status.rawValue
        createdAt = settlement.createdAt
        settledAt = settlement.settledAt
    }
}

private extension JSONDecoder {
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: raw) {
                return date
            }
            let basic = ISO8601DateFormatter()
            basic.formatOptions = [.withInternetDateTime]
            if let date = basic.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date \(raw)")
        }
        return decoder
    }
}

private extension JSONEncoder {
    static var supabase: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        default:
            return nil
        }
    }
}
