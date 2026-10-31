import XCTest

final class LexiDawnUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testAppUsesFullSizeWindowOnModernCISimulator() {
        let app = launch("empty")
        XCTAssertTrue(app.tabBars.buttons["今日"].waitForExistence(timeout: 5))
        capture("today-empty-native-window", in: app)
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
        XCTAssertTrue(app.staticTexts["UI 测试文章（非真实内容）"].waitForExistence(timeout: 5))
        capture("today-ready-isolated-fixture", in: app)
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
            XCTAssertTrue(app.staticTexts["UI 测试文章（非真实内容）"].waitForExistence(timeout: 5))
            capture("today-\(scenario)-isolated-fixture", in: app)
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
        capture("storage-unavailable-isolated-fixture", in: app)
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

    /// User-review evidence from the actual running simulator, retained even when assertions pass.
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

extension LexiDawnUITests {
    func testRound2ReadingLookupVocabularyReviewAndExploreUnlock() throws {
        let app = launchLearningDisk()
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 10)); app.buttons["open-reader"].tap()
        let book = app.buttons["word-Book"].firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10)); book.tap()
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["刚刚加入"].waitForExistence(timeout: 10))
        capture("round2-word-real-dictionary", in: app)
        app.buttons["close-word"].tap()
        app.buttons["finish-reading"].tap()
        app.alerts.buttons["确认我已读完"].tap()
        XCTAssertTrue(app.staticTexts["reading-completed"].waitForExistence(timeout: 5))
        app.buttons["返回今日"].tap()
        XCTAssertFalse(app.staticTexts["cycle-completed"].exists)
        app.tabBars.buttons["词汇"].tap()
        let search = app.searchFields.firstMatch; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("book")
        XCTAssertTrue(app.staticTexts["book"].waitForExistence(timeout: 5))
        app.tabBars.buttons["复习"].tap()
        let word = app.buttons["match-word-book"]
        XCTAssertTrue(word.waitForExistence(timeout: 15)); word.tap()
        let meaning = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "match-meaning-")).firstMatch
        XCTAssertTrue(meaning.waitForExistence(timeout: 5)); meaning.tap()
        let spelling = app.textFields["cloze-answer"]
        XCTAssertTrue(spelling.waitForExistence(timeout: 5)); spelling.tap(); spelling.typeText("book")
        app.buttons["submit-spelling"].tap()
        XCTAssertTrue(app.staticTexts["本次复习已保存"].waitForExistence(timeout: 5))
        capture("round2-two-stage-review-saved", in: app)
        app.tabBars.buttons["今日"].tap()
        XCTAssertTrue(app.staticTexts["cycle-completed"].waitForExistence(timeout: 5))
        app.tabBars.buttons["探索"].tap()
        XCTAssertTrue(app.staticTexts["暂无合法探索内容，可先导入文章。"].waitForExistence(timeout: 5))
        app.tabBars.buttons["词汇"].tap()
        XCTAssertTrue(app.staticTexts["book"].waitForExistence(timeout: 5))
    }
    func testRound2ScrollExitRelaunchRestoresProgressAndRepeatedLookupDoesNotDeleteWord() throws {
        let app = launchLearningDisk()
        app.buttons["open-reader"].tap()
        let book = app.buttons["word-Book"].firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10)); book.tap()
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10)); app.buttons["close-word"].tap()
        book.tap()
        XCTAssertTrue(app.staticTexts["此前已加入"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["undo-word"].exists); app.buttons["close-word"].tap()
        let body = app.descendants(matching: .any)["reader-body"].firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.swipeUp(); body.swipeUp(); body.swipeUp()
        let before = try XCTUnwrap(Int(app.staticTexts["reader-progress"].label.replacingOccurrences(of: "%", with: "")))
        XCTAssertGreaterThan(before, 0)
        let visibleBefore = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "word-")).allElementsBoundByIndex.first { $0.isHittable }
        let offsetBefore = try XCTUnwrap(Int(visibleBefore?.value as? String ?? ""))
        app.buttons["返回今日"].tap(); app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 10)); app.buttons["open-reader"].tap()
        XCTAssertTrue(app.staticTexts["reader-progress"].waitForExistence(timeout: 10))
        let restored = try XCTUnwrap(Int(app.staticTexts["reader-progress"].label.replacingOccurrences(of: "%", with: "")))
        XCTAssertGreaterThanOrEqual(restored, before - 3)
        let visibleAfter = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "word-")).allElementsBoundByIndex.first { $0.isHittable }
        let offsetAfter = try XCTUnwrap(Int(visibleAfter?.value as? String ?? ""))
        XCTAssertLessThan(abs(offsetAfter - offsetBefore), 250, "Must restore the visible text position, not only a numeric progress label")
        capture("round2-reader-restored-after-relaunch", in: app)
        XCTAssertFalse(app.staticTexts["reading-completed"].exists)
    }
    func testRound2SettingsPersistAndDisabledAutoAddRequiresManualAdd() throws {
        let app = launchLearningDisk()
        app.tabBars.buttons["我的"].tap()
        let toggle = app.switches["auto-add"]
        try revealLearning(toggle, in: app); tapNativeSwitch(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        let save = app.buttons["save-settings"]; try revealLearning(save, in: app); save.tap()
        XCTAssertTrue(app.staticTexts["settings-message"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["settings-message"].label, "设置已保存")
        app.terminate(); app.launch(); app.tabBars.buttons["我的"].tap()
        let restored = app.switches["auto-add"]; try revealLearning(restored, in: app)
        XCTAssertEqual(restored.value as? String, "0")
        app.tabBars.buttons["今日"].tap(); app.buttons["open-reader"].tap()
        let book = app.buttons["word-Book"].firstMatch; XCTAssertTrue(book.waitForExistence(timeout: 10)); book.tap()
        let add = app.buttons["add-word"]; XCTAssertTrue(add.waitForExistence(timeout: 10)); XCTAssertFalse(app.staticTexts["刚刚加入"].exists)
        add.tap(); XCTAssertTrue(app.staticTexts["刚刚加入"].waitForExistence(timeout: 5))
        app.buttons["undo-word"].tap(); XCTAssertTrue(app.buttons["add-word"].waitForExistence(timeout: 5))
    }
    func testRound2UserImportsArticleThroughProductionForm() throws {
        let app = launch("round2")
        let importButton = app.buttons["import-article-toolbar"]; XCTAssertTrue(importButton.waitForExistence(timeout: 10)); importButton.tap()
        app.textFields["import-title"].tap(); app.textFields["import-title"].typeText("My owned article")
        let editor = app.textViews["import-body"]; editor.tap(); editor.typeText("A book can help us learn. This text was written for this isolated UI test.")
        let rights = app.switches["import-rights"]; try revealLearning(rights, in: app); tapNativeSwitch(rights)
        XCTAssertEqual(rights.value as? String, "1")
        let save = app.buttons["save-import"]; try revealLearning(save, in: app); save.tap()
        XCTAssertTrue(app.staticTexts["My owned article"].waitForExistence(timeout: 10))
        app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["word-book"].firstMatch.waitForExistence(timeout: 10))
        capture("round2-user-import-native-reader", in: app)
    }
    private func launchLearningDisk() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = "round2-disk"
        app.launchEnvironment["LEXIDAWN_UI_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 10))
        return app
    }
    private func tapNativeSwitch(_ row: XCUIElement) {
        let control = row.switches.firstMatch
        if control.exists { control.tap() } else { row.tap() }
    }
    private func revealLearning(_ element: XCUIElement, in app: XCUIApplication) throws {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        capture("round2-unreachable-control", in: app)
        XCTFail("Control not reachable: \(element)")
        throw NSError(domain: "Round2UI", code: 1)
    }
}

extension LexiDawnUITests {
    func testRound2DictionaryDetailsAndNestedEnglishLookupReturnToReader() throws {
        let app = launchLearningDisk(); app.buttons["open-reader"].tap()
        let book = app.buttons["word-Book"].firstMatch; XCTAssertTrue(book.waitForExistence(timeout: 10)); book.tap()
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10))
        let details = app.buttons["查看详细释义"]
        try revealLearning(details, in: app); details.tap()
        XCTAssertTrue(app.navigationBars["详细释义"].waitForExistence(timeout: 5))
        let science = app.buttons["word-science"].firstMatch
        try revealLearning(science, in: app); science.tap()
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10)); app.buttons["close-word"].tap()
        XCTAssertTrue(app.navigationBars["详细释义"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["查词"].tap()
        app.buttons["close-word"].tap()
        XCTAssertTrue(app.buttons["finish-reading"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["reading-completed"].exists)
        capture("round2-dictionary-navigation-returned", in: app)
    }
}
