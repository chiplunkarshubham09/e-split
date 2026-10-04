import XCTest
@testable import E_split

@MainActor
final class E_splitTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertEqual(AppStrings.appName, "Split Expense")
    }
}
