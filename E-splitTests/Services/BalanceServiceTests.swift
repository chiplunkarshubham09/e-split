import XCTest
@testable import E_split

@MainActor
final class BalanceServiceTests: XCTestCase {
    func testSingleEqualExpense() throws {
        let group = TestMembers.group()
        let expense = makeExpense(group: group, amount: 4000, payer: TestMembers.shubID)
        let balances = try BalanceService.netBalances(
            members: group.members,
            expenses: [expense],
            settlements: []
        )

        XCTAssertEqual(balance(TestMembers.shubID, in: balances), 3000)
        XCTAssertEqual(balance(TestMembers.rahulID, in: balances), -1000)
        XCTAssertEqual(balance(TestMembers.amitID, in: balances), -1000)
        XCTAssertEqual(balance(TestMembers.priyaID, in: balances), -1000)
        XCTAssertEqual(balances.map(\.net).reduce(0, +), 0)
    }

    func testMultiplePayers() throws {
        let group = TestMembers.group()
        let hotel = makeExpense(group: group, amount: 4000, payer: TestMembers.shubID)
        let taxi = makeExpense(group: group, amount: 400, payer: TestMembers.rahulID)
        let balances = try BalanceService.netBalances(
            members: group.members,
            expenses: [hotel, taxi],
            settlements: []
        )
        XCTAssertEqual(balances.map(\.net).reduce(0, +).roundedToMoney, 0)
        XCTAssertEqual(balance(TestMembers.shubID, in: balances), 2900)
        XCTAssertEqual(balance(TestMembers.rahulID, in: balances), -700)
    }

    func testPaidSettlementReducesDebt() throws {
        let group = TestMembers.group()
        let expense = makeExpense(group: group, amount: 4000, payer: TestMembers.shubID)
        let settlement = Settlement(
            groupId: group.id,
            fromUser: TestMembers.rahulID,
            toUser: TestMembers.shubID,
            amount: 1000,
            status: .paid
        )
        let balances = try BalanceService.netBalances(
            members: group.members,
            expenses: [expense],
            settlements: [settlement]
        )
        XCTAssertEqual(balance(TestMembers.rahulID, in: balances), 0)
        XCTAssertEqual(balance(TestMembers.shubID, in: balances), 2000)
        XCTAssertEqual(balances.map(\.net).reduce(0, +).roundedToMoney, 0)
    }

    func testPendingSettlementDoesNotChangeBalances() throws {
        let group = TestMembers.group()
        let expense = makeExpense(group: group, amount: 4000, payer: TestMembers.shubID)
        let settlement = Settlement(
            groupId: group.id,
            fromUser: TestMembers.rahulID,
            toUser: TestMembers.shubID,
            amount: 1000,
            status: .pending
        )
        let balances = try BalanceService.netBalances(
            members: group.members,
            expenses: [expense],
            settlements: [settlement]
        )
        XCTAssertEqual(balance(TestMembers.rahulID, in: balances), -1000)
    }

    func testSimplifiedDebts() throws {
        let group = TestMembers.group()
        let expense = makeExpense(group: group, amount: 4000, payer: TestMembers.shubID)
        let balances = try BalanceService.netBalances(
            members: group.members,
            expenses: [expense],
            settlements: []
        )
        let debts = BalanceService.simplifiedDebts(from: balances)
        XCTAssertEqual(debts.count, 3)
        XCTAssertTrue(debts.allSatisfy { $0.toUserId == TestMembers.shubID })
        XCTAssertEqual(debts.map(\.amount).reduce(0, +), 3000)
    }

    func testZeroSumValidation() {
        XCTAssertThrowsError(try BalanceService.validateZeroSum([UUID(): 10, UUID(): -9]))
        XCTAssertNoThrow(try BalanceService.validateZeroSum([UUID(): 10, UUID(): -10]))
    }

    private func balance(_ userId: UUID, in balances: [MemberBalance]) -> Decimal {
        balances.first { $0.userId == userId }?.net ?? 0
    }

    private func makeExpense(group: ExpenseGroup, amount: Decimal, payer: UUID) -> Expense {
        let inputs = group.members.map {
            SplitParticipantInput(userId: $0.userId, amount: 0, percentage: 0, shares: 1)
        }
        let calculated = try! ExpenseCalculationService.calculateSplits(
            total: amount,
            method: .equal,
            participants: inputs
        )
        let expenseID = UUID()
        return Expense(
            id: expenseID,
            groupId: group.id,
            title: "Hotel",
            amount: amount,
            category: .hotel,
            paidBy: payer,
            createdBy: payer,
            splitMethod: .equal,
            splits: calculated.map {
                ExpenseSplit(expenseId: expenseID, userId: $0.userId, amount: $0.amount)
            }
        )
    }
}
