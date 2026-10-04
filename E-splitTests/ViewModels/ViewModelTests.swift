import XCTest
@testable import E_split

@MainActor
final class ViewModelTests: XCTestCase {
    private var local: InMemoryLocalDataSource!
    private var groups: GroupRepository!
    private var expenses: ExpenseRepository!
    private var settlements: SettlementRepository!
    private var currentUser: MockCurrentUserStore!
    private var notifications: MockNotificationService!

    override func setUp() {
        local = InMemoryLocalDataSource()
        groups = GroupRepository(local: local)
        expenses = ExpenseRepository(local: local)
        settlements = SettlementRepository(local: local)
        currentUser = MockCurrentUserStore()
        notifications = MockNotificationService()
    }

    func testCreateGroupAddsCurrentUserAsAdmin() async throws {
        let viewModel = CreateGroupViewModel(repository: groups, currentUser: currentUser.currentUser)
        viewModel.name = "Goa Trip"
        viewModel.type = .trip
        let group = await viewModel.create()
        XCTAssertNotNil(group)
        XCTAssertEqual(group?.members.count, 1)
        XCTAssertEqual(group?.members.first?.role, .admin)
        XCTAssertEqual(group?.members.first?.userId, currentUser.currentUser.id)
    }

    func testCreateGroupRequiresName() async {
        let viewModel = CreateGroupViewModel(repository: groups, currentUser: currentUser.currentUser)
        let group = await viewModel.create()
        XCTAssertNil(group)
        XCTAssertEqual(viewModel.errorMessage, AppError.groupNameRequired.localizedDescription)
    }

    func testAddMember() async throws {
        let group = try await createGroup()
        let viewModel = AddMemberViewModel(repository: groups, group: group)
        viewModel.name = "Rahul"
        let success = await viewModel.add()
        XCTAssertTrue(success)
        let latest = try await groups.fetchGroup(id: group.id)
        XCTAssertEqual(latest?.members.count, 2)
    }

    func testAddMemberUnknownEmailShowsAccountRequired() async throws {
        let group = try await createGroup()
        let remote = StubRemoteBackend()
        remote.addMemberError = AppError.memberNeedsAccount
        let repo = GroupRepository(local: local, remote: remote)
        let viewModel = AddMemberViewModel(repository: repo, group: group)
        viewModel.name = "Rahul"
        viewModel.email = "rahul@example.com"
        let success = await viewModel.add()
        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.errorMessage, AppError.memberNeedsAccount.localizedDescription)
        XCTAssertNotEqual(viewModel.errorMessage, AppError.saveFailed.localizedDescription)
    }

    func testAddExpenseEqualSplit() async throws {
        var group = try await createGroup()
        let rahul = GroupMember(userId: TestMembers.rahulID, groupId: group.id, name: "Rahul", role: .member)
        try await groups.addMember(rahul)
        group = try await groups.fetchGroup(id: group.id)!

        let viewModel = AddExpenseViewModel(
            group: group,
            expenseRepository: expenses,
            currentUserID: currentUser.currentUser.id,
            notificationService: notifications
        )
        viewModel.title = "Dinner"
        viewModel.amountText = "2500"
        viewModel.splitMethod = .equal
        let saved = await viewModel.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(notifications.addedCount, 1)

        let stored = try await expenses.fetchExpenses(groupId: group.id)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.splits.count, 2)
        XCTAssertEqual(stored.first?.splits.map(\.amount).reduce(0, +), 2500)
    }

    func testAddExpenseRejectsEmptyDescription() async throws {
        let group = try await createGroup()
        let viewModel = AddExpenseViewModel(
            group: group,
            expenseRepository: expenses,
            currentUserID: currentUser.currentUser.id,
            notificationService: notifications
        )
        viewModel.amountText = "100"
        let saved = await viewModel.save()
        XCTAssertFalse(saved)
        XCTAssertEqual(viewModel.errorMessage, AppError.descriptionRequired.localizedDescription)
    }

    func testDeleteExpense() async throws {
        let group = try await createGroup()
        let viewModel = AddExpenseViewModel(
            group: group,
            expenseRepository: expenses,
            currentUserID: currentUser.currentUser.id,
            notificationService: notifications
        )
        viewModel.title = "Taxi"
        viewModel.amountText = "150"
        _ = await viewModel.save()
        let expense = try await expenses.fetchExpenses(groupId: group.id).first!

        let detail = ExpenseDetailViewModel(
            expense: expense,
            group: group,
            currentUserID: currentUser.currentUser.id,
            expenseRepository: expenses
        )
        let deleted = await detail.delete()
        XCTAssertTrue(deleted)
        let remaining = try await expenses.fetchExpenses(groupId: group.id)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testRecordAndMarkSettlementPaid() async throws {
        let group = TestMembers.group()
        try await groups.createGroup(group)
        let inputs = group.members.map {
            SplitParticipantInput(userId: $0.userId, amount: 0, percentage: 0, shares: 1)
        }
        let calculated = try ExpenseCalculationService.calculateSplits(total: 4000, method: .equal, participants: inputs)
        let expenseID = UUID()
        let expense = Expense(
            id: expenseID,
            groupId: group.id,
            title: "Hotel",
            amount: 4000,
            category: .hotel,
            paidBy: TestMembers.shubID,
            createdBy: TestMembers.shubID,
            splitMethod: .equal,
            splits: calculated.map {
                ExpenseSplit(expenseId: expenseID, userId: $0.userId, amount: $0.amount)
            }
        )
        try await expenses.saveExpense(expense)

        let viewModel = SettlementsViewModel(
            group: group,
            currentUserID: TestMembers.shubID,
            expenseRepository: expenses,
            repository: settlements,
            notificationService: notifications
        )
        viewModel.load(expenses: [expense], settlements: [], members: group.members)
        let debt = viewModel.availableDebts.first { $0.fromUserId == TestMembers.rahulID }
        XCTAssertNotNil(debt)
        await viewModel.record(debt!)
        XCTAssertEqual(viewModel.pending.count, 1)
        await viewModel.markPaid(viewModel.pending[0])
        XCTAssertEqual(viewModel.paid.count, 1)
        XCTAssertEqual(viewModel.paid.first?.status, .paid)
    }

    private func createGroup() async throws -> ExpenseGroup {
        let viewModel = CreateGroupViewModel(repository: groups, currentUser: currentUser.currentUser)
        viewModel.name = "Home"
        guard let group = await viewModel.create() else {
            struct Failed: Error {}
            throw Failed()
        }
        return group
    }
}
