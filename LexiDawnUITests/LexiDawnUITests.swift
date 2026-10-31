import XCTest

final class LexiDawnUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testAppUsesFullSizeWindowOnModernCISimulator() {
        let app = launch("empty")
        XCTAssertTrue(app.tabBars.buttons["今日"].waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(window.width, 375, "Modern simulator must not use a legacy 320x480 window: \(window)")
        XCTAssertGreaterThanOrEqual(window.height, 667, "Modern simulator must not use a legacy 320x480 window: \(window)")
    }

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

    func testUnavailableButtonsAreDisabledAndReloadDoesNotChangeReadyStates() throws {
        let app = launch("ready")
        try assertTaskState(app, expected: "待开始")
        for task in ["article", "review", "matching", "cloze"] {
            let button = app.buttons["unavailable-\(task)"]
            try reveal(button, in: app)
            XCTAssertTrue(button.exists)
            XCTAssertFalse(button.isEnabled)
            // A coordinate tap verifies the disabled control does not issue a domain write.
            XCTAssertTrue(isVisible(button, in: app))
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        try reload(app)
        try assertTaskState(app, expected: "待开始")
        XCTAssertFalse(app.staticTexts["本周期已完成"].exists)
    }

    func testBlockedAndFailedReasonsExplainUnavailableRecoveryAndRemainUnchanged() throws {
        for scenario in ["blocked", "failed"] {
            let app = launch(scenario)
            try assertTaskState(app, expected: scenario == "blocked" ? "被阻塞" : "执行失败")
            for task in ["article", "review", "matching", "cloze"] {
                let reason = app.staticTexts["reason-\(task)"]
                try reveal(reason, in: app)
                XCTAssertTrue(reason.label.contains("真实失败原因"))
            }
            let explanation = app.staticTexts["unavailable-explanation"]
            try reveal(explanation, in: app)
            XCTAssertTrue(explanation.label.contains("尚不能恢复学习"))
            for task in ["article", "review", "matching", "cloze"] {
                let button = app.buttons["unavailable-\(task)"]
                try reveal(button, in: app)
                XCTAssertFalse(button.isEnabled)
                XCTAssertTrue(isVisible(button, in: app))
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            try reload(app)
            try assertTaskState(app, expected: scenario == "blocked" ? "被阻塞" : "执行失败")
            app.terminate()
        }
    }

    func testHistoricalInProgressBecomesExplainedBlockedWithoutChangingArticle() throws {
        let app = launch("inProgress")
        XCTAssertTrue(app.staticTexts["UI 测试文章（非真实内容）"].waitForExistence(timeout: 5))
        try assertTaskState(app, expected: "被阻塞")
        for task in ["article", "review", "matching", "cloze"] {
            let reason = app.staticTexts["reason-\(task)"]
            try reveal(reason, in: app)
            XCTAssertTrue(reason.label.contains("功能尚未接入"))
        }
        try reload(app)
        try assertTaskState(app, expected: "被阻塞")
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
    /// Scroll only the intended view, in the direction of the target. No fixed up/down cycles.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) throws {
        let scroll = app.scrollViews["today-scroll"]
        guard scroll.waitForExistence(timeout: 5), element.waitForExistence(timeout: 5) else {
            try positioningFailure("Missing scroll view or target \(element.identifier)", app: app, file: file, line: line)
            return
        }
        for attempt in 0..<8 {
            let viewport = usableViewport(in: app)
            let before = element.frame
            guard !viewport.isEmpty, !viewport.isNull, !before.isEmpty else {
                try positioningFailure("Empty geometry: target=\(before), viewport=\(viewport)", app: app, file: file, line: line)
                return
            }
            if viewport.contains(CGPoint(x: before.midX, y: before.midY)) { return }
            if before.midX < viewport.minX || before.midX > viewport.maxX {
                try positioningFailure("Target is horizontally clipped: \(before), viewport=\(viewport)", app: app, file: file, line: line)
                return
            }
            if before.midY < viewport.minY { scroll.swipeDown() } else { scroll.swipeUp() }
            let after = element.frame
            if abs(after.midY - before.midY) < 1 && !isVisible(element, in: app) {
                try positioningFailure("Scroll made no progress on attempt \(attempt + 1): target=\(after), viewport=\(viewport)", app: app, file: file, line: line)
                return
            }
        }
        try positioningFailure("Target remains outside viewport after 8 directed gestures: \(element.identifier)", app: app, file: file, line: line)
    }

    private func usableViewport(in app: XCUIApplication) -> CGRect {
        let window = app.windows.firstMatch.frame
        let scroll = app.scrollViews["today-scroll"].frame
        let intersection = window.intersection(scroll)
        guard !intersection.isNull, !intersection.isEmpty else { return .zero }
        let navigation = app.navigationBars.firstMatch
        let tabs = app.tabBars.firstMatch
        let top = navigation.exists ? max(intersection.minY, navigation.frame.maxY) : intersection.minY
        let bottom = tabs.exists ? min(intersection.maxY, tabs.frame.minY) : intersection.maxY
        guard bottom > top else { return .zero }
        return CGRect(x: intersection.minX + 2, y: top + 2, width: max(0, intersection.width - 4), height: max(0, bottom - top - 4))
    }

    private func isVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        return !frame.isEmpty && usableViewport(in: app).contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    private func positioningFailure(_ message: String, app: XCUIApplication, file: StaticString, line: UInt) throws {
        XCTContext.runActivity(named: "UI positioning failure: \(message)") { activity in
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            activity.add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Accessibility hierarchy and geometry"
            hierarchy.lifetime = .keepAlways
            activity.add(hierarchy)
        }
        XCTFail(message, file: file, line: line)
        throw NSError(domain: "LexiDawnUIPositioning", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func reload(_ app: XCUIApplication) throws {
        let button = app.buttons["reload-cycle"]
        try reveal(button, in: app)
        button.tap()
        XCTAssertTrue(app.staticTexts["status-article"].waitForExistence(timeout: 5))
    }

    private func assertTaskState(_ app: XCUIApplication, expected: String) throws {
        for task in ["article", "review", "matching", "cloze"] {
            let status = app.staticTexts["status-\(task)"]
            try reveal(status, in: app)
            XCTAssertTrue(status.waitForExistence(timeout: 5))
            XCTAssertEqual(status.label, expected)
        }
    }
}
