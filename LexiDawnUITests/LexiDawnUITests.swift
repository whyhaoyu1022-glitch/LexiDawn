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
        capture("F20-isolated-daily-task-ready", in: app)
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 10)); app.buttons["open-reader"].tap()
        let book = app.buttons["word-Book"].firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10)); book.tap()
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["刚刚加入"].waitForExistence(timeout: 10))
        capture("round2-word-real-dictionary", in: app)
        app.buttons["close-word"].tap()
        app.buttons["finish-reading"].tap()
        capture("F21-reading-manual-confirmation", in: app)
        app.alerts.buttons["确认我已读完"].tap()
        XCTAssertTrue(app.staticTexts["reading-completed"].waitForExistence(timeout: 5))
        capture("F22-reading-completion-saved", in: app)
        app.buttons["返回今日"].tap()
        XCTAssertFalse(app.staticTexts["cycle-completed"].exists)
        capture("F23-reading-done-review-outstanding", in: app)
        app.tabBars.buttons["词汇"].tap()
        let search = app.searchFields.firstMatch; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("book")
        XCTAssertTrue(app.staticTexts["book"].waitForExistence(timeout: 5))
        capture("F24-vocabulary-search-book", in: app)
        let cancelSearch = app.buttons["Cancel"].firstMatch
        if cancelSearch.exists { cancelSearch.tap() }
        else if app.buttons["取消"].firstMatch.exists { app.buttons["取消"].firstMatch.tap() }
        else if app.buttons["Close"].firstMatch.exists { app.buttons["Close"].firstMatch.tap() }
        XCTAssertTrue(app.tabBars.buttons["复习"].isHittable)
        app.tabBars.buttons["复习"].tap()
        XCTAssertTrue(app.navigationBars["复习"].waitForExistence(timeout: 5))
        let word = app.buttons["match-word-book"]
        XCTAssertTrue(word.waitForExistence(timeout: 15)); capture("F25-review-matching-ready", in: app); word.tap()
        let meaning = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "match-meaning-")).firstMatch
        XCTAssertTrue(meaning.waitForExistence(timeout: 5)); meaning.tap()
        let spelling = app.textFields["cloze-answer"]
        XCTAssertTrue(spelling.waitForExistence(timeout: 5)); capture("F26-review-spelling-stage", in: app); spelling.tap(); spelling.typeText("book"); capture("F27-review-spelling-keyboard", in: app)
        app.buttons["submit-spelling"].tap()
        XCTAssertTrue(app.staticTexts["本次复习已保存"].waitForExistence(timeout: 5))
        capture("round2-two-stage-review-saved", in: app)
        app.tabBars.buttons["今日"].tap()
        XCTAssertTrue(app.staticTexts["cycle-completed"].waitForExistence(timeout: 5))
        capture("F28-daily-cycle-completed", in: app)
        app.tabBars.buttons["探索"].tap()
        XCTAssertTrue(app.staticTexts["暂无合法探索内容，可先导入文章。"].waitForExistence(timeout: 5))
        capture("F29-explore-unlocked-honest-empty", in: app)
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
        XCTAssertFalse(app.buttons["undo-word"].exists); capture("F30-existing-word-safe-no-undo", in: app); app.buttons["close-word"].tap()
        let body = app.descendants(matching: .any)["reader-body"].firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.swipeUp(); body.swipeUp(); body.swipeUp()
        let before = try XCTUnwrap(Int(app.staticTexts["reader-progress"].label.replacingOccurrences(of: "%", with: "")))
        XCTAssertGreaterThan(before, 0)
        let visibleBefore = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "word-")).allElementsBoundByIndex.first { $0.isHittable }
        let offsetBefore = try XCTUnwrap(Int(visibleBefore?.value as? String ?? ""))
        app.buttons["返回今日"].tap(); app.terminate(); app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        let continueReading = app.buttons["open-reader"]
        XCTAssertTrue(continueReading.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in continueReading.exists && continueReading.isHittable }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        // Re-read current geometry after relaunch; send one real touch to the native control.
        continueReading.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["英文阅读"].waitForExistence(timeout: 10))
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
        capture("F31-auto-add-disabled-restored", in: app)
        app.tabBars.buttons["今日"].tap(); app.buttons["open-reader"].tap()
        let book = app.buttons["word-Book"].firstMatch; XCTAssertTrue(book.waitForExistence(timeout: 10)); book.tap()
        let add = app.buttons["add-word"]; XCTAssertTrue(add.waitForExistence(timeout: 10)); XCTAssertFalse(app.staticTexts["刚刚加入"].exists)
        capture("F32-word-with-auto-add-off", in: app)
        add.tap(); XCTAssertTrue(app.staticTexts["刚刚加入"].waitForExistence(timeout: 5))
        capture("F33-word-manual-add-saved", in: app)
        app.buttons["undo-word"].tap(); XCTAssertTrue(app.buttons["add-word"].waitForExistence(timeout: 5))
        capture("F34-word-new-add-safely-undone", in: app)
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
        let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.name = "round2-unreachable-hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
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
        capture("F35-dictionary-detail-before-nested-lookup", in: app)
        let science = app.links["science"].firstMatch
        try revealLearning(science, in: app); science.tap()
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10)); capture("F36-nested-science-lookup", in: app); app.buttons["close-word"].tap()
        XCTAssertTrue(app.navigationBars["详细释义"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["查词"].tap()
        app.buttons["close-word"].tap()
        XCTAssertTrue(app.buttons["finish-reading"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["reading-completed"].exists)
        capture("round2-dictionary-navigation-returned", in: app)
    }
}

// Review gallery: real simulator captures, not rendered mockups. P = production RFC,
// S = real RFC with seeded learning state, F = explicitly owned test article, X = injected fault.
extension LexiDawnUITests {
    func testGalleryProductionFirstLaunchAndRFCReading() throws {
        // No UI scenario override: exercise the actual production dependency factory and store.
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["The Internet is for End Users"].exists)
        capture("P01-production-today-real-rfc", in: app)
        app.tabBars.buttons["探索"].tap()
        XCTAssertTrue(app.staticTexts["先完成必做，再自由探索"].waitForExistence(timeout: 5))
        capture("P02-production-explore-locked", in: app)
        app.buttons["继续今日任务"].tap()
        app.buttons["open-reader"].tap()
        XCTAssertTrue(app.navigationBars["英文阅读"].waitForExistence(timeout: 10))
        capture("P03-production-rfc-reader-top", in: app)
        app.buttons["来源与许可"].tap()
        capture("P04-production-rfc-source-attribution", in: app)
        app.buttons["来源与许可"].tap()
        let internet = app.buttons["word-Internet"].firstMatch
        XCTAssertTrue(internet.waitForExistence(timeout: 10)); internet.tap()
        XCTAssertTrue(app.staticTexts["刚刚加入"].waitForExistence(timeout: 10))
        capture("P05-production-rfc-internet-lookup-added", in: app)
        app.swipeUp()
        capture("P06-production-dictionary-possible-meanings", in: app)
        let details = app.buttons["查看详细释义"]
        try revealLearning(details, in: app); details.tap()
        XCTAssertTrue(app.navigationBars["详细释义"].waitForExistence(timeout: 5))
        capture("P07-production-dictionary-detail", in: app)
        app.swipeUp(); app.swipeUp()
        capture("P08-production-dictionary-context-and-license", in: app)
        app.navigationBars.buttons["查词"].tap(); app.buttons["close-word"].tap()
        let body = app.descendants(matching: .any)["reader-body"].firstMatch
        for index in 1...3 { body.swipeUp(); capture("P\(String(format: "%02d", index + 8))-production-rfc-scroll-\(index)", in: app) }
        for _ in 0..<8 { body.swipeUp() }
        capture("P17-production-real-rfc-main-discussion", in: app)
        XCTAssertGreaterThan(Int(app.staticTexts["reader-progress"].label.replacingOccurrences(of: "%", with: "")) ?? 0, 0)
        app.buttons["finish-reading"].tap()
        XCTAssertTrue(app.alerts["明确确认已读完"].waitForExistence(timeout: 5))
        capture("P12-production-manual-completion-confirmation", in: app)
        app.alerts.buttons["取消"].tap()
        capture("P13-production-reading-still-in-progress", in: app)
        app.buttons["返回今日"].tap()
        capture("P14-production-today-saved-progress", in: app)
        app.swipeUp(); app.swipeUp()
        capture("P15-production-statistics-and-content-actions", in: app)
        let library = app.buttons["article-library"]
        try revealLearning(library, in: app); library.tap()
        XCTAssertTrue(app.navigationBars["文章库与历史"].waitForExistence(timeout: 5))
        capture("P16-production-library-real-rfc-history", in: app)
    }

    func testGalleryRealRFCReaderAppearanceAndOrientation() throws {
        let app = launchGallery("gallery-rfc")
        app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["finish-reading"].waitForExistence(timeout: 10))
        for (index, theme) in ["浅色", "深色", "暖纸色"].enumerated() {
            try openReaderAppearance(app)
            XCTAssertTrue(app.buttons[theme].waitForExistence(timeout: 5)); app.buttons[theme].tap()
            capture("P2\(index)-real-rfc-theme-\(index)", in: app)
        }
        try openReaderAppearance(app)
        capture("P23-real-rfc-reader-appearance-menu", in: app)
        app.buttons["增大字号"].tap()
        capture("P24-real-rfc-larger-font", in: app)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["finish-reading"].waitForExistence(timeout: 5))
        capture("P25-real-rfc-landscape", in: app)
        XCUIDevice.shared.orientation = .portrait
        app.buttons["返回今日"].tap(); app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 10)); app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["finish-reading"].waitForExistence(timeout: 10))
        capture("P26-real-rfc-theme-survives-relaunch", in: app)
    }

    func testGalleryImportEmptyValidationAndOwnedArticle() throws {
        let app = launchGallery("gallery-empty")
        XCTAssertTrue(app.staticTexts["准备第一篇英文阅读"].waitForExistence(timeout: 10))
        capture("F01-learning-empty-no-candidate", in: app)
        app.tabBars.buttons["词汇"].tap()
        XCTAssertTrue(app.staticTexts["还没有匹配的生词"].waitForExistence(timeout: 5))
        capture("F02-vocabulary-empty", in: app)
        app.tabBars.buttons["复习"].tap()
        XCTAssertTrue(app.staticTexts["请先在今日页获得文章，并在阅读中积累词汇。"].waitForExistence(timeout: 5))
        capture("F03-review-no-cycle", in: app)
        app.tabBars.buttons["今日"].tap(); app.buttons["import-article-toolbar"].tap()
        XCTAssertTrue(app.textFields["import-title"].waitForExistence(timeout: 5))
        capture("F04-import-blank-form", in: app)
        let rights = app.switches["import-rights"]
        try revealLearning(rights, in: app)
        let save = app.buttons["save-import"]
        for _ in 0..<6 {
            if save.exists && save.frame.midY < app.windows.firstMatch.frame.maxY - 80 { break }
            app.swipeUp()
        }
        XCTAssertTrue(save.exists); XCTAssertFalse(save.isEnabled)
        capture("F05-import-without-rights-save-disabled", in: app)
        try revealLearning(rights, in: app); tapNativeSwitch(rights)
        try revealLearning(save, in: app); save.tap()
        XCTAssertTrue(app.staticTexts["请填写有效标题、来源和主题。"].waitForExistence(timeout: 5))
        capture("X01-import-empty-title-validation", in: app)
        app.swipeDown(); app.swipeDown()
        app.textFields["import-title"].tap(); app.textFields["import-title"].typeText("My screenshot article (test-owned)")
        let editor = app.textViews["import-body"]; editor.tap(); editor.typeText("A book opens a window to science. I wrote this short passage for this isolated screenshot test. We learn by reading, remembering, and trying again. Lexidawngalleryword is deliberately an unknown word.")
        app.swipeUp()
        capture("F06-import-owned-text-preview", in: app)
        try revealLearning(save, in: app); save.tap()
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 10))
        capture("F07-owned-import-assigned-today", in: app)
        app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["word-book"].firstMatch.waitForExistence(timeout: 10))
        capture("F08-owned-import-native-reader", in: app)
        app.descendants(matching: .any)["reader-body"].firstMatch.swipeUp()
        let unknown = app.buttons["word-Lexidawngalleryword"].firstMatch
        XCTAssertTrue(unknown.waitForExistence(timeout: 10)); unknown.tap()
        let noResult = app.staticTexts["暂无可验证的释义。可以继续阅读，或在生词本添加明确标记的个人释义。"]
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 5))
        // A long headword fills the medium sheet; List creates the no-result row
        // only after the user expands/scrolls it. Reveal before asserting existence.
        try revealLearning(noResult, in: app)
        XCTAssertTrue(noResult.waitForExistence(timeout: 5))
        capture("F09-dictionary-honest-no-result", in: app)
    }

    func testGalleryRealRFCVocabularySearchNotesAndRemove() throws {
        let app = launchGallery("gallery-review")
        app.tabBars.buttons["词汇"].tap()
        XCTAssertTrue(app.staticTexts["internet"].waitForExistence(timeout: 5))
        capture("S01-vocabulary-real-rfc-two-entries", in: app)
        app.buttons["短语"].tap()
        XCTAssertTrue(app.staticTexts["还没有匹配的生词"].waitForExistence(timeout: 5))
        capture("S02-vocabulary-phrase-filter-empty", in: app)
        app.buttons["全部"].tap()
        let search = app.searchFields.firstMatch; search.tap(); search.typeText("internet")
        XCTAssertTrue(app.staticTexts["internet"].waitForExistence(timeout: 5))
        capture("S03-vocabulary-search-hit", in: app)
        closeGallerySearch(app)
        app.staticTexts["internet"].tap()
        XCTAssertTrue(app.textFields["personal-meaning"].waitForExistence(timeout: 5))
        capture("S04-vocabulary-detail-personal-meaning", in: app)
        let notes = app.textFields["笔记"].firstMatch
        if notes.exists { notes.tap(); notes.typeText(" - Reviewed in the real RFC") }
        app.buttons["保存个人释义与笔记"].tap()
        XCTAssertTrue(app.staticTexts["已保存"].waitForExistence(timeout: 5))
        capture("S05-vocabulary-notes-saved", in: app)
        let remove = app.buttons["手动移除词条"]; try revealLearning(remove, in: app)
        capture("S06-vocabulary-real-source-context", in: app)
        remove.tap(); XCTAssertTrue(app.alerts["确认移除词条"].waitForExistence(timeout: 5))
        capture("S07-vocabulary-delete-confirmation", in: app)
        app.alerts.buttons["取消"].tap()
        XCTAssertTrue(app.navigationBars["internet"].exists)
        remove.tap(); app.alerts.buttons["确认移除"].tap()
        XCTAssertTrue(app.navigationBars["生词本"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["internet"].exists)
        capture("S08-vocabulary-manual-delete-result", in: app)
    }

    func testGalleryReviewWrongAnswersHintsAndRestoredSession() throws {
        let app = launchGallery("gallery-review")
        app.tabBars.buttons["复习"].tap()
        let internet = app.buttons["match-word-internet"]
        XCTAssertTrue(internet.waitForExistence(timeout: 15))
        capture("S10-review-matching-two-real-words", in: app)
        app.buttons["match-meaning-互联网（个人释义）"].tap()
        XCTAssertEqual(app.staticTexts["review-feedback"].label, "请先选择英文词条")
        capture("S11-review-select-word-first", in: app)
        internet.tap(); app.buttons["match-meaning-文档（个人释义）"].tap()
        XCTAssertTrue(app.staticTexts["review-feedback"].label.contains("还不正确"))
        capture("S12-review-incorrect-match", in: app)
        internet.tap(); app.buttons["match-meaning-互联网（个人释义）"].tap()
        capture("S13-review-partial-matching-saved", in: app)
        app.terminate(); app.launch(); app.tabBars.buttons["复习"].tap()
        let document = app.buttons["match-word-document"]
        XCTAssertTrue(document.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["match-word-internet"].isEnabled)
        capture("S14-review-session-restored", in: app)
        document.tap(); app.buttons["match-meaning-文档（个人释义）"].tap()
        let answer = app.textFields["cloze-answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        capture("S15-review-spelling-stable-mask", in: app)
        answer.tap(); answer.typeText("wrong")
        capture("S16-review-spelling-keyboard-input", in: app)
        app.buttons["submit-spelling"].tap()
        XCTAssertTrue(app.staticTexts["review-feedback"].label.contains("还不正确"))
        try revealLearning(app.staticTexts["review-feedback"], in: app)
        capture("S17-review-spelling-wrong-answer", in: app)
        app.buttons["使用提示"].tap()
        XCTAssertTrue(app.staticTexts["review-feedback"].label.contains("首字母"))
        try revealLearning(app.staticTexts["review-feedback"], in: app)
        capture("S18-review-hint-saved", in: app)
        app.buttons["忘记了，显示答案"].tap()
        try revealLearning(app.staticTexts["review-feedback"], in: app)
        capture("S19-review-reveal-again-grade", in: app)
        XCTAssertTrue(answer.waitForExistence(timeout: 5)); answer.tap(); answer.typeText("document")
        app.buttons["submit-spelling"].tap()
        XCTAssertTrue(app.staticTexts["本次复习已保存"].waitForExistence(timeout: 5))
        capture("S20-review-completed-reading-outstanding", in: app)
        app.tabBars.buttons["探索"].tap()
        XCTAssertTrue(app.staticTexts["还需完成阅读"].waitForExistence(timeout: 5))
        capture("S21-review-complete-explore-still-locked", in: app)
    }

    func testGalleryRealRFCLicenseExpiryBackoffAndOverdue() throws {
        let expired = launchGallery("gallery-expired")
        XCTAssertTrue(expired.buttons["open-reader"].waitForExistence(timeout: 10))
        capture("X10-expired-license-metadata-retained", in: expired)
        expired.buttons["open-reader"].tap()
        XCTAssertTrue(expired.staticTexts["暂时无法读取全文"].waitForExistence(timeout: 10))
        XCTAssertFalse(expired.descendants(matching: .any)["reader-body"].exists)
        capture("X11-expired-license-body-blocked-source-retry", in: expired)
        expired.buttons["重新读取"].tap()
        XCTAssertTrue(expired.staticTexts["暂时无法读取全文"].exists)
        capture("X12-expired-license-retry-preserves-denial", in: expired)
        expired.terminate()
        let backoff = launchGallery("gallery-backoff")
        let refresh = backoff.buttons["从官方来源刷新"]; try revealLearning(refresh, in: backoff); refresh.tap()
        XCTAssertTrue(backoff.staticTexts["来源仍在退避期，请稍后重试。"].waitForExistence(timeout: 5))
        try revealLearning(backoff.staticTexts["来源仍在退避期，请稍后重试。"], in: backoff)
        capture("X13-official-source-backoff-real-error-view", in: backoff)
        backoff.terminate()
        let overdue = launchGallery("gallery-overdue")
        XCTAssertTrue(overdue.buttons["open-reader"].waitForExistence(timeout: 10))
        capture("S30-overdue-original-real-rfc-preserved", in: overdue)
        overdue.tabBars.buttons["探索"].tap()
        capture("S31-overdue-explore-original-date-locked", in: overdue)
        overdue.terminate()
        let corrupt = launchGallery("gallery-missing-state")
        corrupt.tabBars.buttons["复习"].tap()
        let error = corrupt.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "不能证明队列为空")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        capture("X14-review-missing-state-blocks-empty-proof", in: corrupt)
    }

    func testGallerySettingsSavedAndContentLicenses() throws {
        let app = launchGallery("gallery-rfc")
        app.tabBars.buttons["复习"].tap()
        XCTAssertTrue(app.staticTexts["完整队列中没有应复习词条，已记录合法空队列结果。"].waitForExistence(timeout: 10))
        capture("P36-review-verified-empty-queue", in: app)
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.textFields["settings-name"].waitForExistence(timeout: 5))
        capture("P30-settings-profile-and-reader-controls", in: app)
        app.textFields["settings-name"].tap(); app.textFields["settings-name"].typeText("Lexi Reader\n")
        let theme = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "阅读主题")).firstMatch; try revealLearning(theme, in: app); theme.tap()
        capture("P31-settings-theme-choices", in: app)
        app.buttons["暖纸色"].tap()
        let auto = app.switches["auto-add"]; try revealLearning(auto, in: app); tapNativeSwitch(auto)
        capture("P32-settings-auto-add-disabled", in: app)
        let save = app.buttons["save-settings"]; try revealLearning(save, in: app); save.tap()
        XCTAssertEqual(app.staticTexts["settings-message"].label, "设置已保存")
        capture("P33-settings-review-timezone-and-saved", in: app)
        let licenses = app.buttons["内容与词典许可"]; try revealLearning(licenses, in: app); licenses.tap()
        XCTAssertTrue(app.navigationBars["来源与许可"].waitForExistence(timeout: 5))
        capture("P34-settings-license-source-text", in: app)
        app.swipeUp(); capture("P35-settings-dictionary-license", in: app)
    }

    private func launchGallery(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = scenario
        app.launchEnvironment["LEXIDAWN_UI_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["今日"].waitForExistence(timeout: 15))
        return app
    }
    private func closeGallerySearch(_ app: XCUIApplication) {
        for label in ["Cancel", "取消", "Close"] where app.buttons[label].firstMatch.exists { app.buttons[label].firstMatch.tap(); return }
    }
    private func openReaderAppearance(_ app: XCUIApplication) throws {
        let menu = app.buttons["阅读外观"]
        if !menu.exists || !menu.isHittable {
            for label in ["More", "更多", "More Options", "更多选项"] where app.navigationBars.buttons[label].exists { app.navigationBars.buttons[label].tap(); break }
        }
        XCTAssertTrue(menu.waitForExistence(timeout: 5)); menu.tap()
    }
}
