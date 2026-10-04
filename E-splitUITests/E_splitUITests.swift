import XCTest

final class E_splitUITests: XCTestCase {
    func testLoginScreenLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Log in"].waitForExistence(timeout: 5) || app.navigationBars["Groups"].waitForExistence(timeout: 2))
    }
}
