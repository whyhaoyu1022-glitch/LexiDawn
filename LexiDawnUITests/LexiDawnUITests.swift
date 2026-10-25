import XCTest

final class LexiDawnUITests: XCTestCase {
    func testFivePrimaryTabsAreVisibleAndSelectable() {
        let app = XCUIApplication()
        app.launch()
        for label in ["今日", "探索", "词汇", "复习", "我的"] {
            let tab = app.tabBars.buttons[label]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab: \(label)")
            tab.tap()
            XCTAssertTrue(app.navigationBars[label].waitForExistence(timeout: 5), "Missing navigation title: \(label)")
        }
    }
}
