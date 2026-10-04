import XCTest
@testable import E_split

@MainActor
final class ExpenseCalculationServiceTests: XCTestCase {
    func testEqualSplit() throws {
        let splits = try ExpenseCalculationService.calculateSplits(
            total: 4000,
            method: .equal,
            participants: participants(count: 4)
        )
        XCTAssertEqual(splits.map(\.amount), [1000, 1000, 1000, 1000])
    }

    func testEqualSplitRounding() throws {
        let splits = try ExpenseCalculationService.calculateSplits(
            total: 100,
            method: .equal,
            participants: participants(count: 3)
        )
        let total = splits.reduce(Decimal.moneyZero) { $0 + $1.amount }
        XCTAssertEqual(total, 100)
        XCTAssertEqual(splits.map(\.amount).max()! - splits.map(\.amount).min()!, MoneyRounding.fromMinorUnits(1))
    }

    func testExactAmountSplit() throws {
        let inputs = [
            SplitParticipantInput(userId: TestMembers.shubID, amount: 1500, percentage: 0, shares: 0),
            SplitParticipantInput(userId: TestMembers.rahulID, amount: 1000, percentage: 0, shares: 0),
            SplitParticipantInput(userId: TestMembers.amitID, amount: 500, percentage: 0, shares: 0),
            SplitParticipantInput(userId: TestMembers.priyaID, amount: 1000, percentage: 0, shares: 0)
        ]
        let splits = try ExpenseCalculationService.calculateSplits(
            total: 4000,
            method: .exactAmount,
            participants: inputs
        )
        XCTAssertEqual(splits.map(\.amount), [1500, 1000, 500, 1000])
    }

    func testExactAmountRejectsInvalidTotal() {
        let inputs = [
            SplitParticipantInput(userId: TestMembers.shubID, amount: 100, percentage: 0, shares: 0)
        ]
        XCTAssertThrowsError(
            try ExpenseCalculationService.calculateSplits(total: 4000, method: .exactAmount, participants: inputs)
        )
    }

    func testPercentageSplit() throws {
        let inputs = [
            SplitParticipantInput(userId: TestMembers.shubID, amount: 0, percentage: 40, shares: 0),
            SplitParticipantInput(userId: TestMembers.rahulID, amount: 0, percentage: 20, shares: 0),
            SplitParticipantInput(userId: TestMembers.amitID, amount: 0, percentage: 20, shares: 0),
            SplitParticipantInput(userId: TestMembers.priyaID, amount: 0, percentage: 20, shares: 0)
        ]
        let splits = try ExpenseCalculationService.calculateSplits(
            total: 4000,
            method: .percentage,
            participants: inputs
        )
        XCTAssertEqual(splits.map(\.amount), [1600, 800, 800, 800])
    }

    func testPercentageMustTotalOneHundred() {
        let inputs = [
            SplitParticipantInput(userId: TestMembers.shubID, amount: 0, percentage: 50, shares: 0)
        ]
        XCTAssertThrowsError(
            try ExpenseCalculationService.calculateSplits(total: 100, method: .percentage, participants: inputs)
        )
    }

    func testSharesSplit() throws {
        let inputs = [
            SplitParticipantInput(userId: TestMembers.shubID, amount: 0, percentage: 0, shares: 2),
            SplitParticipantInput(userId: TestMembers.rahulID, amount: 0, percentage: 0, shares: 1),
            SplitParticipantInput(userId: TestMembers.amitID, amount: 0, percentage: 0, shares: 1),
            SplitParticipantInput(userId: TestMembers.priyaID, amount: 0, percentage: 0, shares: 2)
        ]
        let splits = try ExpenseCalculationService.calculateSplits(
            total: 4000,
            method: .shares,
            participants: inputs
        )
        XCTAssertEqual(splits.map(\.amount), [1333.33, 666.67, 666.67, 1333.33])
        let total = splits.reduce(Decimal.moneyZero) { $0 + $1.amount }
        XCTAssertEqual(total, 4000)
    }

    func testInvalidShares() {
        let inputs = [
            SplitParticipantInput(userId: TestMembers.shubID, amount: 0, percentage: 0, shares: 0)
        ]
        XCTAssertThrowsError(
            try ExpenseCalculationService.calculateSplits(total: 100, method: .shares, participants: inputs)
        )
    }

    func testAmountMustBePositive() {
        XCTAssertThrowsError(
            try ExpenseCalculationService.calculateSplits(
                total: 0,
                method: .equal,
                participants: participants(count: 2)
            )
        )
    }

    func testRequiresParticipants() {
        XCTAssertThrowsError(
            try ExpenseCalculationService.calculateSplits(total: 100, method: .equal, participants: [])
        )
    }

    private func participants(count: Int) -> [SplitParticipantInput] {
        (0..<count).map { _ in
            SplitParticipantInput(userId: UUID(), amount: 0, percentage: 0, shares: 1)
        }
    }
}
