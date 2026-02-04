import XCTest

final class GoogleMaps3DDemoUITests: XCTestCase {
    func testLaunchAndOpenAgGuidanceDemo() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let agGuidanceCell = app.staticTexts["Ag Guidance Demo"]
        XCTAssertTrue(agGuidanceCell.waitForExistence(timeout: 5))
        agGuidanceCell.tap()

        let tasksButton = app.buttons["Tasks"]
        XCTAssertTrue(tasksButton.waitForExistence(timeout: 5))
    }
}
