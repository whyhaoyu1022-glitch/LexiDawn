import XCTest

final class LexiDawnUITests: XCTestCase {
    func testFivePrimaryTabsAreVisibleAndSelectable() {
        let app = launch("empty")
        for label in ["今日", "探索", "词汇", "复习", "我的"] {
            let tab = app.tabBars.buttons[label]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab: \(label)")
            tab.tap()
            XCTAssertTrue(app.navigationBars[label].waitForExistence(timeout: 5))
        }
    }

    func testTodayShowsHonestEmptyStateWhenNoArticleProviderIsConnected() {
        let app = launch("empty")
        XCTAssertTrue(app.staticTexts["暂时没有可分配文章"].waitForExistence(timeout: 5))
        app.buttons["重试"].tap()
        XCTAssertTrue(app.staticTexts["暂时没有可分配文章"].exists)
    }

    func testUnavailableButtonsAreDisabledAndReloadDoesNotChangeReadyStates() {
        let app = launch("ready")
        assertTaskState(app, expected: "待开始")
        for task in ["article", "review", "matching", "cloze"] {
            let button = app.buttons["unavailable-\(task)"]
            reveal(button, in: app)
            XCTAssertTrue(button.exists)
            XCTAssertFalse(button.isEnabled)
            // A coordinate tap verifies the disabled control does not issue a domain write.
            XCTAssertTrue(isVisible(button, in: app))
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        reload(app)
        assertTaskState(app, expected: "待开始")
        XCTAssertFalse(app.staticTexts["本周期已完成"].exists)
    }

    func testBlockedAndFailedReasonsExplainUnavailableRecoveryAndRemainUnchanged() {
        for scenario in ["blocked", "failed"] {
            let app = launch(scenario)
            assertTaskState(app, expected: scenario == "blocked" ? "被阻塞" : "执行失败")
            for task in ["article", "review", "matching", "cloze"] {
                let reason = app.staticTexts["reason-\(task)"]
                reveal(reason, in: app)
                XCTAssertTrue(reason.label.contains("真实失败原因"))
            }
            let explanation = app.staticTexts["unavailable-explanation"]
            reveal(explanation, in: app)
            XCTAssertTrue(explanation.label.contains("尚不能恢复学习"))
            for task in ["article", "review", "matching", "cloze"] {
                let button = app.buttons["unavailable-\(task)"]
                reveal(button, in: app)
                XCTAssertFalse(button.isEnabled)
                XCTAssertTrue(isVisible(button, in: app))
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            reload(app)
            assertTaskState(app, expected: scenario == "blocked" ? "被阻塞" : "执行失败")
            app.terminate()
        }
    }

    func testHistoricalInProgressBecomesExplainedBlockedWithoutChangingArticle() {
        let app = launch("inProgress")
        XCTAssertTrue(app.staticTexts["UI 测试文章（非真实内容）"].waitForExistence(timeout: 5))
        assertTaskState(app, expected: "被阻塞")
        for task in ["article", "review", "matching", "cloze"] {
            let reason = app.staticTexts["reason-\(task)"]
            reveal(reason, in: app)
            XCTAssertTrue(reason.label.contains("功能尚未接入"))
        }
        reload(app)
        assertTaskState(app, expected: "被阻塞")
    }

    func testStartupFailureHasRealRetryAndNeverPretendsDataLoaded() {
        let app = launch("startupFailure")
        XCTAssertTrue(app.staticTexts["本地学习数据暂时不可用"].waitForExistence(timeout: 5))
        app.buttons["retry-storage"].tap()
        XCTAssertTrue(app.staticTexts["本地学习数据暂时不可用"].exists)
        XCTAssertFalse(app.tabBars.buttons["今日"].exists)
    }

    func testStartupRetryRepeatsInitializationAndLoadsApp() {
        let app = launch("startupRetry")
        XCTAssertTrue(app.staticTexts["本地学习数据暂时不可用"].waitForExistence(timeout: 5))
        app.buttons["retry-storage"].tap()
        XCTAssertTrue(app.tabBars.buttons["今日"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["暂时没有可分配文章"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["本地学习数据暂时不可用"].exists)
    }

    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = scenario
        app.launch()
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if isVisible(element, in: app) { return }
            app.swipeUp()
        }
    }
    private func isVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists else { return false }
        let viewport = app.scrollViews.firstMatch.frame
        let frame = element.frame
        return !frame.isEmpty && viewport.contains(CGPoint(x: frame.midX, y: frame.midY))
    }
    private func reload(_ app: XCUIApplication) {
        let button = app.buttons["reload-cycle"]
        reveal(button, in: app)
        button.tap()
        for _ in 0..<6 { app.swipeDown() }
    }
    private func assertTaskState(_ app: XCUIApplication, expected: String) {
        for _ in 0..<6 { app.swipeDown() }
        for task in ["article", "review", "matching", "cloze"] {
            let status = app.staticTexts["status-\(task)"]
            reveal(status, in: app)
            XCTAssertTrue(status.waitForExistence(timeout: 5))
            XCTAssertEqual(status.label, expected)
        }
    }
}
