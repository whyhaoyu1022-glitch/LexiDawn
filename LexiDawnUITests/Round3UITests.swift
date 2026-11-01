import XCTest
import UIKit
import ImageIO

final class Round3UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false; XCUIDevice.shared.orientation = .portrait }
    override func tearDownWithError() throws {
        // This isolated fixture contains no live discovery candidates or user data.
        // Retain its failure hierarchy in the log even if artifact upload is unavailable.
        if name.contains("testVocabularyStatusSortConfirmedMeaningAndNativeExportDialogs"), (testRun?.failureCount ?? 0) > 0 {
            let hierarchy = XCUIApplication().debugDescription
            print("ROUND3_EXPORT_FAILURE_HIERARCHY_BEGIN\n" + hierarchy + "\nROUND3_EXPORT_FAILURE_HIERARCHY_END")
            let attachment = XCTAttachment(string: hierarchy)
            attachment.name = "round3-export-failure-hierarchy"; attachment.lifetime = .keepAlways; add(attachment)
        }
    }
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication(); app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = scenario
        app.launchEnvironment["LEXIDAWN_UI_STORE_ID"] = UUID().uuidString; app.launch(); return app
    }
    private func choose(_ identifier: String, option: String, app: XCUIApplication) throws {
        let picker = app.buttons[identifier]
        for _ in 0..<7 { if picker.exists && picker.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(picker.isHittable); picker.tap()
        let value = try XCTUnwrap(app.buttons.matching(NSPredicate(format: "label == %@", option)).allElementsBoundByIndex.first(where: \.isHittable)); value.tap()
    }
    func testStructuredOriginalReaderShowsHeadingsQuoteAndList() throws {
        let app = launch("round3-reader-structure")
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
        let body = app.otherElements["reader-body"].firstMatch; XCTAssertTrue(body.exists)
        XCTAssertTrue(app.buttons["word-Original"].firstMatch.waitForExistence(timeout: 10))
        capture("R3-R10", app: app, feature: "reader", state: "structured-original-headings-and-quotation", origin: "explicit-original-HTML-through-real-extractor-and-Repository")
        let listItem = app.buttons["word-First"].firstMatch
        for _ in 0..<6 {
            if listItem.exists && listItem.isHittable { break }
            let start = body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        XCTAssertTrue(listItem.isHittable)
        capture("R3-R11", app: app, feature: "reader", state: "original-list-and-natural-paragraphs", origin: "explicit-original-HTML-through-real-extractor-and-Repository")
    }
    func testPersonalOriginalUpdateFormAndChangedVersionRestoreNativeReader() throws {
        let app = launch("round3-version-change"); openLibrary(app)
        let edit = app.buttons["更新个人原文"].firstMatch
        for _ in 0..<7 { if edit.exists && edit.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(edit.isHittable); edit.tap(); XCTAssertTrue(app.navigationBars["更新个人原文"].waitForExistence(timeout: 10))
        let title = app.textFields["import-title"]; XCTAssertTrue(title.exists); title.tap(); title.typeText(" verified")
        let rights = app.switches["import-rights"]
        for _ in 0..<7 { if rights.exists && rights.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(rights.isHittable); let toggle = rights.switches.firstMatch; if toggle.exists { toggle.tap() } else { rights.tap() }
        capture("R3-R12", app: app, feature: "reader-version", state: "explicit-owned-original-update-confirmation", origin: "explicit-original-version-fixture-real-Repository-update")
        let save = app.buttons["save-import"]
        for _ in 0..<5 { if save.exists && save.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(save.isEnabled); XCTAssertTrue(save.isHittable); save.tap()
        XCTAssertTrue(app.navigationBars["文章库与历史"].waitForExistence(timeout: 10))
        let read = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'")).firstMatch
        for _ in 0..<8 { if read.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(read.isHittable); read.tap()
        let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '正文版本已变化'")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 10)); XCTAssertTrue(visibleWord(in: app).isHittable)
        capture("R3-R13", app: app, feature: "reader-version", state: "new-complete-original-restores-unique-old-paragraph", origin: "explicit-original-version-fixture-real-Repository-update")
    }
    func testLibraryCategoryTimeSortAndCompletedHistory() throws {
        let app = launch("round3-explore-catalog"); openLibrary(app)
        try choose("library-topic-filter", option: "Science", app: app)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'")).count, 1)
        capture("R3-L10", app: app, feature: "library", state: "category-filter-science", origin: "explicit-original-catalog-fixture-real-domain-evidence")
        try choose("library-topic-filter", option: "全部分类", app: app)
        let order = app.switches["最新导入优先"]; XCTAssertTrue(order.exists)
        let toggle = order.switches.firstMatch; if toggle.exists { toggle.tap() } else { order.tap() }
        capture("R3-L11", app: app, feature: "library", state: "oldest-import-first", origin: "explicit-original-catalog-fixture-real-domain-evidence")
        try choose("library-mode-filter", option: "历史", app: app)
        let completed = app.staticTexts["已完成 · 可重读"]
        for _ in 0..<5 { if completed.exists && completed.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(completed.exists)
        capture("R3-L12", app: app, feature: "library", state: "completed-article-in-local-history", origin: "explicit-original-catalog-fixture-real-domain-evidence")
    }
    func testVocabularyStatusSortConfirmedMeaningAndNativeExportDialogs() throws {
        let app = launch("gallery-review"); app.tabBars.buttons["词汇"].tap()
        try choose("vocabulary-status-filter", option: "待复习", app: app)
        capture("R3-V10", app: app, feature: "vocabulary", state: "due-status-filter", origin: "real-RFC-explicit-personal-vocabulary-fixture")
        try choose("vocabulary-sort", option: "字母顺序", app: app)
        capture("R3-V11", app: app, feature: "vocabulary", state: "alphabetical-sort-with-due-dates", origin: "real-RFC-explicit-personal-vocabulary-fixture")
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vocabulary-entry-'")).firstMatch
        for _ in 0..<6 { if entry.exists && entry.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(entry.isHittable); entry.tap()
        let picker = app.buttons["choose-review-meaning"]
        for _ in 0..<7 { if picker.exists && picker.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(picker.isHittable); picker.tap()
        let sense = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'review-meaning-'")).firstMatch
        for _ in 0..<5 { if sense.exists && sense.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(sense.isHittable); sense.tap()
        XCTAssertTrue(app.staticTexts["复习义项已保存"].waitForExistence(timeout: 10))
        capture("R3-V12", app: app, feature: "vocabulary", state: "explicit-source-meaning-saved", origin: "real-local-CEDICT-with-explicit-user-selection")
        app.navigationBars.buttons["生词本"].tap()
        for (index, title) in ["导出 JSON（完整学习数据）", "导出 CSV"].enumerated() {
            app.buttons["vocabulary-export"].tap(); app.buttons[title].tap()
            let filename = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'LexiDawn-vocabulary' OR value CONTAINS 'LexiDawn-vocabulary'")).firstMatch
            let exporterBar = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
            XCTAssertTrue(exporterBar.waitForExistence(timeout: 15))
            XCTAssertTrue(filename.waitForExistence(timeout: 15))
            let expectedName = index == 0 ? "LexiDawn-vocabulary.json" : "LexiDawn-vocabulary.csv"
            XCTAssertEqual(app.staticTexts["vocabulary-export-filename"].label, expectedName)
            if index == 0 {
                app.buttons["cancel-vocabulary-export"].tap()
                expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: exporterBar)
                waitForExpectations(timeout: 10)
                XCTAssertFalse(app.staticTexts["vocabulary-export-completed"].exists)
                capture("R3-V18", app: app, feature: "vocabulary-export", state: "cancelled-export-no-success-feedback", origin: "real-repository-staged-file-native-document-picker-fixture-vocabulary")
                app.buttons["vocabulary-export"].tap(); app.buttons[title].tap()
                XCTAssertTrue(exporterBar.waitForExistence(timeout: 15))
                XCTAssertTrue(filename.waitForExistence(timeout: 15))
            }
            capture("R3-V\(index + 14)", app: app, feature: "vocabulary-export", state: index == 0 ? "native-JSON-export-dialog" : "native-CSV-export-dialog", origin: "real-repository-staged-file-native-document-picker-fixture-vocabulary")
            let save = exporterBar.buttons.matching(NSPredicate(format: "label IN %@", ["Save", "保存", "存储"])).firstMatch
            expectation(for: NSPredicate { _, _ in save.exists && save.isEnabled && save.isHittable }, evaluatedWith: save)
            waitForExpectations(timeout: 15)
            save.tap()
            let completed = app.staticTexts["vocabulary-export-completed"]
            XCTAssertTrue(completed.waitForExistence(timeout: 30))
            XCTAssertTrue(completed.label.contains(expectedName))
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: exporterBar)
            waitForExpectations(timeout: 10)
            XCTAssertTrue(app.navigationBars["生词本"].waitForExistence(timeout: 10))
            capture("R3-V\(index + 16)", app: app, feature: "vocabulary-export", state: index == 0 ? "system-JSON-copy-completed" : "system-CSV-copy-completed", origin: "native-document-picker-completion-callback-not-preset-success")
        }
        let search = app.searchFields.firstMatch
        for _ in 0..<5 { if search.exists && search.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(search.isHittable); search.tap(); search.typeText("zzzzunfindable")
        XCTAssertTrue(app.staticTexts["还没有匹配的生词"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vocabulary-entry-'")).count, 0)
        capture("R3-V13", app: app, feature: "vocabulary", state: "typed-search-no-result", origin: "real-RFC-explicit-personal-vocabulary-fixture")
    }
    private func capture(_ id: String, app: XCUIApplication, feature: String, state: String, theme: String = "system", origin: String = "fixture-real-rfc-isolated-learning-state") {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? UIDevice.current.name
        let identifier = id + "-" + device.map { $0.isLetter || $0.isNumber || $0 == "-" ? String($0) : "-" }.joined()
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = identifier; image.lifetime = .keepAlways; add(image)
        let metadata: [String: String] = ["screenshotID": identifier, "featureID": feature, "screenName": feature, "state": state,
            "device": ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? UIDevice.current.name, "orientation": XCUIDevice.shared.orientation.isLandscape ? "landscape" : "portrait", "theme": theme,
            "testName": name, "fixtureOrProduction": origin, "fileName": identifier + ".png", "notes": "Native Simulator screenshot; no image generation."]
        if let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]) {
            let json = XCTAttachment(data: data, uniformTypeIdentifier: "public.json"); json.name = identifier + "-metadata"; json.lifetime = .keepAlways; add(json)
        }
    }
    func testHistoricalFavoriteLaterAndHistoryStayLockedUntilCurrentTaskFinishes() throws {
        let app = launch("round3-history-gate"); openLibrary(app)
        let historical = app.buttons["library-open-rfc-editor-8890"]
        for _ in 0..<5 { if historical.exists { break }; app.swipeUp() }
        XCTAssertTrue(historical.waitForExistence(timeout: 10)); XCTAssertFalse(historical.isEnabled)
        capture("R3-LOCK01", app: app, feature: "article-gate", state: "historical-daily-article-locked", origin: "explicit-historical-cycle-fixture-real-domain-evidence")
        for (index, filter) in ["收藏", "稍后阅读", "历史"].enumerated() {
            let picker = app.buttons["library-mode-filter"]
            for _ in 0..<5 { if picker.exists && picker.isHittable { break }; app.swipeDown() }
            XCTAssertTrue(picker.isHittable); picker.tap()
            let option = try XCTUnwrap(app.buttons.matching(NSPredicate(format: "label == %@", filter)).allElementsBoundByIndex.first(where: \.isHittable))
            option.tap()
            for _ in 0..<5 { if historical.exists && historical.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(historical.exists); XCTAssertFalse(historical.isEnabled)
            capture("R3-LOCK0\(index + 2)", app: app, feature: "article-gate", state: filter + "-cannot-open-old-daily-article", origin: "explicit-historical-cycle-fixture-real-domain-evidence")
        }
    }
    func testQuickMeaningIsBoundedAndFullScreenDetailKeepsAllSenses() throws {
        let app = launch("round3-dictionary-many")
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["word-Internet"].firstMatch.waitForExistence(timeout: 10)); app.buttons["word-Internet"].firstMatch.tap()
        let count = app.staticTexts["共 6 条义项 · 完整释义见左上角词典"]
        XCTAssertTrue(count.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Explicit original definition number 6 for the dictionary presentation test."].exists)
        capture("R3-D40", app: app, feature: "dictionary", state: "bounded-two-sense-quick-meaning", origin: "explicit-original-six-sense-provider-fixture")
        app.buttons["查看详细释义"].tap(); XCTAssertTrue(app.navigationBars["详细释义"].waitForExistence(timeout: 10))
        let last = app.staticTexts["Explicit original definition number 6 for the dictionary presentation test."].firstMatch
        for _ in 0..<10 { if last.exists && last.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(last.exists); XCTAssertTrue(last.isHittable)
        capture("R3-D41", app: app, feature: "dictionary", state: "full-screen-all-six-senses-grouped-by-pos", origin: "explicit-original-six-sense-provider-fixture")
        app.navigationBars.buttons["查词"].tap(); XCTAssertTrue(app.buttons["close-word"].exists)
        capture("R3-D42", app: app, feature: "dictionary", state: "detail-returns-to-original-quick-meaning", origin: "explicit-original-six-sense-provider-fixture")
    }
    func testExtraReviewRestartsSameQuestionAndDoesNotRelockExplore() throws {
        let app = launch("round3-extra-review"); app.tabBars.buttons["复习"].tap()
        XCTAssertTrue(app.staticTexts["extra-review-label"].waitForExistence(timeout: 15))
        capture("R3-E01", app: app, feature: "extra-review", state: "new-extra-session-after-required-completion", origin: "explicit-extra-review-fixture-real-domain-evidence")
        let word = app.buttons["match-word-internet"]; XCTAssertTrue(word.exists); word.tap(); app.buttons["match-meaning-互联网（额外复习夹具）"].tap()
        app.terminate(); app.launch(); app.tabBars.buttons["复习"].tap()
        XCTAssertTrue(app.staticTexts["extra-review-label"].waitForExistence(timeout: 10))
        XCTAssertTrue(word.exists); XCTAssertFalse(word.isEnabled)
        capture("R3-E02", app: app, feature: "extra-review", state: "restart-restores-extra-pair-progress", origin: "explicit-extra-review-fixture-real-domain-evidence")
        app.buttons["match-word-document"].tap(); app.buttons["match-meaning-文档（额外复习夹具）"].tap()
        for answer in ["internet", "document"] {
            let field = app.textFields["cloze-answer"]; XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText(answer); app.buttons["submit-spelling"].tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["review-completed"].firstMatch.waitForExistence(timeout: 10))
        capture("R3-E03", app: app, feature: "extra-review", state: "extra-results-and-next-due-saved", origin: "explicit-extra-review-fixture-real-domain-evidence")
        app.tabBars.buttons["探索"].tap(); XCTAssertFalse(app.staticTexts["先完成必做，再自由探索"].exists)
        capture("R3-E04", app: app, feature: "extra-review", state: "daily-unlock-unchanged-after-extra-session", origin: "explicit-extra-review-fixture-real-domain-evidence")
    }
    func testExploreCardsFavoritesAndConfirmedResetPreserveNativeReadingFlow() throws {
        let app = launch("round3-explore-catalog"); app.tabBars.buttons["探索"].tap()
        let open = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'explore-open-'")).firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 10)); let identity = open.identifier
        capture("R3-X01", app: app, feature: "explore", state: "ranked-native-fulltext-cards", origin: "explicit-original-catalog-fixture-real-domain-evidence")
        open.tap(); XCTAssertTrue(app.navigationBars["英文阅读"].waitForExistence(timeout: 10)); app.buttons["关闭"].tap()
        XCTAssertFalse(app.buttons[identity].exists)
        app.buttons["explore-library"].tap()
        let reset = app.buttons["重新标记为未开始"].firstMatch
        for _ in 0..<8 { if reset.exists && reset.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(reset.isHittable); reset.tap()
        let confirm = app.buttons["确认重新标记"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["英文阅读"].exists)
        XCTAssertFalse(app.navigationBars["更新个人原文"].exists)
        app.buttons["取消"].tap()
        XCTAssertTrue(app.navigationBars["文章库与历史"].exists)
        XCTAssertTrue(reset.isHittable); reset.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        capture("R3-X02", app: app, feature: "explore", state: "explicit-reset-confirmation-keeps-history", origin: "explicit-original-catalog-fixture-real-domain-evidence")
        confirm.tap()
        app.navigationBars.buttons["探索"].tap()
        XCTAssertTrue(app.buttons[identity].waitForExistence(timeout: 10))
        capture("R3-X03", app: app, feature: "explore", state: "confirmed-reset-restores-unstarted-recommendation", origin: "explicit-original-catalog-fixture-real-domain-evidence")
    }
    func testVocabularyRecommendationsLockAndRequireExplicitAddAfterDetail() throws {
        var app = launch("gallery-reader"); app.tabBars.buttons["词汇"].tap(); app.buttons["vocabulary-recommendations"].tap()
        XCTAssertTrue(app.staticTexts["完成必做后，开启词汇推荐"].waitForExistence(timeout: 10))
        capture("R3-N01", app: app, feature: "word-recommendation", state: "locked-with-current-task", origin: "explicit-isolated-RFC-learning-state")
        app.terminate(); app = launch("round3-recommendations-many"); app.tabBars.buttons["词汇"].tap(); app.buttons["vocabulary-recommendations"].tap()
        let add = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recommendation-add-'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 20)); XCTAssertEqual(add.label, "加入生词本")
        capture("R3-N02", app: app, feature: "word-recommendation", state: "real-article-candidates-with-explicit-fixture-definitions", origin: "explicit-original-article-and-provider-fixture")
        let detail = app.buttons["查看详细释义"].firstMatch
        for _ in 0..<4 { if detail.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(detail.isHittable); detail.tap()
        XCTAssertTrue(app.navigationBars["详细释义"].waitForExistence(timeout: 10)); XCTAssertTrue(app.buttons["加入生词本"].exists)
        capture("R3-N03", app: app, feature: "word-recommendation", state: "detail-does-not-auto-add", origin: "explicit-original-article-and-provider-fixture")
        app.navigationBars.buttons["词汇推荐"].tap()
        XCTAssertTrue(add.exists); XCTAssertEqual(add.label, "加入生词本"); add.tap()
        XCTAssertEqual(add.label, "已加入生词本")
        capture("R3-N04", app: app, feature: "word-recommendation", state: "explicit-add-persisted", origin: "explicit-original-article-and-provider-fixture")
        app.navigationBars.buttons["生词本"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vocabulary-entry-'")).count, 1)
    }
    func testVocabularyRecommendationLoadingEmptyAndFailureStates() throws {
        for (index, mode) in ["loading", "empty", "all-failed"].enumerated() {
            let app = launch("round3-recommendations-" + mode); app.tabBars.buttons["词汇"].tap(); app.buttons["vocabulary-recommendations"].tap()
            if mode == "loading" { XCTAssertTrue(app.descendants(matching: .any)["recommendation-loading"].firstMatch.waitForExistence(timeout: 10)) }
            else if mode == "empty" { XCTAssertTrue(app.staticTexts["暂无新的推荐词条"].waitForExistence(timeout: 15)) }
            else { XCTAssertTrue(app.staticTexts["推荐词典暂时不可用；生词本与学习记录保留，请重试。"].waitForExistence(timeout: 15)) }
            capture("R3-N\(index + 5)", app: app, feature: "word-recommendation", state: mode, origin: "explicit-original-provider-fault-fixture")
            app.terminate()
        }
    }
    func testReaderBodySurvivesTenRotationsAndWordRemainsTappable() throws {
        let app = launch("gallery-reader")
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["word-Internet"].firstMatch.waitForExistence(timeout: 10))
        capture("R3-R01", app: app, feature: "reader", state: "portrait-body-visible")
        for index in 0..<10 {
            XCUIDevice.shared.orientation = index.isMultiple(of: 2) ? .landscapeLeft : .portrait
            let token = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'word-'")).firstMatch
            XCTAssertTrue(token.waitForExistence(timeout: 8)); XCTAssertTrue(token.isHittable, "Visible text is required after rotation \(index)")
            XCTAssertGreaterThan(token.frame.width, 2); XCTAssertGreaterThan(token.frame.height, 5)
            let body = app.otherElements["reader-body"].firstMatch
            XCTAssertGreaterThanOrEqual(body.frame.width, app.windows.firstMatch.frame.width * 0.80, "The reader must use the rotated viewport width")
            if index == 0 { capture("R3-R02", app: app, feature: "reader", state: "landscape-body-visible") }
        }
        let body = app.otherElements["reader-body"].firstMatch
        XCTAssertTrue(body.exists); body.swipeUp()
        capture("R3-R03", app: app, feature: "reader", state: "scrolled-after-ten-rotations")
        let token = visibleWord(in: app)
        XCTAssertTrue(token.isHittable); token.tap()
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10))
        capture("R3-R04", app: app, feature: "dictionary", state: "word-tap-after-rotation")
    }
    func testMatchingDrawsVisibleLinesDisablesBothEndsAndRotates() throws {
        let app = launch("gallery-round3-review"); app.tabBars.buttons["复习"].tap()
        let internet = app.buttons["match-word-internet"]
        XCTAssertTrue(internet.waitForExistence(timeout: 15))
        capture("R3-M01", app: app, feature: "matching", state: "initial-three-pairs")
        internet.tap(); capture("R3-M02", app: app, feature: "matching", state: "selected-word")
        app.buttons["match-meaning-文档（个人释义）"].tap()
        XCTAssertTrue(app.staticTexts["review-feedback"].label.contains("还不正确"))
        capture("R3-M03", app: app, feature: "matching", state: "wrong-pair-feedback")
        internet.tap(); app.buttons["match-meaning-互联网（个人释义）"].tap()
        XCTAssertFalse(internet.isEnabled); XCTAssertFalse(app.buttons["match-meaning-互联网（个人释义）"].isEnabled)
        XCTAssertGreaterThan(greenLinePixels(app: app), 12, "A real rendered line must cross the column gap")
        capture("R3-M04", app: app, feature: "matching", state: "one-visible-line-both-ends-disabled")
        app.buttons["match-word-document"].tap(); app.buttons["match-meaning-文档（个人释义）"].tap()
        XCTAssertGreaterThan(greenLinePixels(app: app), 24)
        capture("R3-M05", app: app, feature: "matching", state: "two-visible-lines")
        XCUIDevice.shared.orientation = .landscapeLeft
        let settled = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
        expectation(for: settled, evaluatedWith: app); waitForExpectations(timeout: 10)
        XCTAssertGreaterThan(greenLinePixels(app: app), 12)
        capture("R3-M06", app: app, feature: "matching", state: "landscape-lines")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["match-word-book"].tap(); app.buttons["match-meaning-书（个人释义）"].tap()
        XCTAssertTrue(app.textFields["cloze-answer"].waitForExistence(timeout: 10))
        capture("R3-M07", app: app, feature: "review", state: "matching-complete-spelling-context")
        app.buttons["show-completed-matches"].tap()
        for text in ["internet", "document", "book"] { let word = app.buttons["match-word-" + text]; XCTAssertTrue(word.exists); XCTAssertFalse(word.isEnabled) }
        XCTAssertGreaterThan(greenLinePixels(app: app), 24)
        capture("R3-M08", app: app, feature: "matching", state: "all-three-completed-connections-retained")
        let board = app.otherElements["matching-board"].firstMatch
        let previousY = board.frame.minY
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.7)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6)))
        XCTAssertLessThan(board.frame.minY, previousY)
        XCTAssertGreaterThan(greenLinePixels(app: app), 12)
        capture("R3-M11", app: app, feature: "matching", state: "completed-lines-remain-anchored-after-scroll")
    }
    func testLiveColdStartImportReadingLookupPersonalMeaningReviewAndRestart() throws {
        let app = launch("round3-network")
        let origin = "production-network-empty-isolated-store-explicit-user-meaning"
        capture("R3-C01", app: app, feature: "article", state: "cold-empty-before-network", origin: origin)
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 120), "Real complete article discovery must succeed; no seeded article or completed state")
        capture("R3-C02", app: app, feature: "article", state: "live-complete-import-assigned", origin: origin)
        app.buttons["open-reader"].tap()
        XCTAssertTrue(app.navigationBars["英文阅读"].waitForExistence(timeout: 10))
        let body = app.otherElements["reader-body"].firstMatch; XCTAssertTrue(body.exists); body.swipeUp()
        let token = visibleWord(in: app)
        XCTAssertTrue(token.waitForExistence(timeout: 10)); XCTAssertTrue(token.isHittable)
        let actualSurface = token.label; XCTAssertFalse(actualSurface.isEmpty); token.tap()
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10))
        capture("R3-C03", app: app, feature: "dictionary", state: "live-word-lookup-new-vocabulary", origin: origin)
        app.buttons["close-word"].tap(); app.buttons["返回今日"].tap(); app.tabBars.buttons["词汇"].tap()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vocabulary-entry-'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        let lemma = String(entry.identifier.dropFirst("vocabulary-entry-".count)); XCTAssertFalse(lemma.isEmpty); entry.tap()
        let personal = app.textFields["personal-meaning"]; XCTAssertTrue(personal.waitForExistence(timeout: 10))
        personal.tap(); personal.typeText("学习测试个人释义（明确用户填写）")
        let save = app.buttons["保存个人释义与笔记"]
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertTrue(save.isHittable); save.tap()
        XCTAssertTrue(app.staticTexts["已保存"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        capture("R3-C04", app: app, feature: "vocabulary", state: "explicit-personal-meaning-saved", origin: origin)
        app.navigationBars.buttons["生词本"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        XCTAssertTrue(personal.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value == %@", "学习测试个人释义（明确用户填写）"), evaluatedWith: personal)
        waitForExpectations(timeout: 10)
        XCTAssertEqual(personal.value as? String, "学习测试个人释义（明确用户填写）")
        app.tabBars.buttons["今日"].tap()
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 10)); app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["finish-reading"].waitForExistence(timeout: 10)); app.buttons["finish-reading"].tap()
        if app.alerts.buttons["确认我已读完"].waitForExistence(timeout: 2) { app.alerts.buttons["确认我已读完"].tap() }
        XCTAssertTrue(app.staticTexts["reading-completed"].waitForExistence(timeout: 10)); app.buttons["返回今日"].tap()
        app.tabBars.buttons["复习"].tap()
        let question = app.buttons["match-word-" + lemma]; XCTAssertTrue(question.waitForExistence(timeout: 90)); question.tap()
        let meaning = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'match-meaning-'")).firstMatch
        XCTAssertTrue(meaning.waitForExistence(timeout: 10)); meaning.tap()
        let spelling = app.textFields["cloze-answer"]; XCTAssertTrue(spelling.waitForExistence(timeout: 10))
        capture("R3-C05", app: app, feature: "review", state: "live-import-derived-spelling", origin: origin)
        XCTAssertTrue(app.staticTexts["cloze-context"].label.contains("_"))
        spelling.tap(); spelling.typeText(actualSurface); app.buttons["submit-spelling"].tap()
        XCTAssertTrue(app.staticTexts["本次复习已保存"].waitForExistence(timeout: 10))
        capture("R3-C06", app: app, feature: "review", state: "review-and-fsrs-saved", origin: origin)
        app.tabBars.buttons["今日"].tap(); XCTAssertTrue(app.staticTexts["cycle-completed"].waitForExistence(timeout: 10))
        app.tabBars.buttons["探索"].tap(); XCTAssertTrue(app.staticTexts["已解锁 · 本地合法文章"].waitForExistence(timeout: 10))
        capture("R3-C07", app: app, feature: "explore", state: "cold-live-cycle-unlocks-explore", origin: origin)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["cycle-completed"].waitForExistence(timeout: 20))
        capture("R3-C08", app: app, feature: "cycle", state: "real-process-restart-restores-completion", origin: origin)
    }
    private func openLibrary(_ app: XCUIApplication) {
        let button = app.buttons["article-library"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        for _ in 0..<6 { if button.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(button.isHittable); button.tap()
        XCTAssertTrue(app.navigationBars["文章库与历史"].waitForExistence(timeout: 10))
    }
    func testInjectedImportFailureMatrixDiscardsEveryCandidate() throws {
        let cases = [("offline", "R3-A10"), ("403", "R3-A11"), ("429", "R3-A12"), ("503", "R3-A13"), ("rights", "R3-A14"), ("parse", "R3-A15"), ("truncated", "R3-A16"), ("summary", "R3-A17"), ("404", "R3-A22"), ("save-failed", "R3-A23")]
        for (mode, id) in cases {
            let app = launch("round3-import-" + mode); openLibrary(app)
            app.buttons["发现完整文章"].tap()
            let error = app.staticTexts["无法导入完整文章，未添加到本地文章库。"]
            XCTAssertTrue(error.waitForExistence(timeout: 25))
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'")).count, 0)
            XCTAssertFalse(app.staticTexts["Explicit fixture article (not production)"].exists)
            capture(id, app: app, feature: "article", state: "discarded-" + mode, origin: "URLProtocol-injected-fault-not-production-network")
            app.terminate()
        }
    }
    func testImportRetryDedupSearchFavoritesAndLocalRestart() throws {
        let app = launch("round3-import-retry"); openLibrary(app)
        capture("R3-L01", app: app, feature: "library", state: "empty-before-import", origin: "explicit-original-fixture-URLProtocol")
        app.buttons["发现完整文章"].tap()
        XCTAssertTrue(app.staticTexts["article-notice"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["article-notice"].label.contains("已导入 1"))
        capture("R3-A18", app: app, feature: "article", state: "503-retry-success-full-import", origin: "URLProtocol-retry-with-original-test-text")
        app.buttons["发现完整文章"].tap()
        XCTAssertTrue(app.staticTexts["article-notice"].waitForExistence(timeout: 10))
        let notice = app.staticTexts["article-notice"]
        let noNew = NSPredicate(format: "label CONTAINS '没有新文章'")
        expectation(for: noNew, evaluatedWith: notice); waitForExpectations(timeout: 15)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'")).count, 1)
        capture("R3-A19", app: app, feature: "article", state: "deduplicated-no-new-article", origin: "explicit-original-fixture-URLProtocol")
        let search = app.searchFields.firstMatch
        for _ in 0..<4 { if search.exists && search.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 10)); XCTAssertTrue(search.isHittable)
        search.tap(); search.typeText("Explicit fixture")
        capture("R3-L02", app: app, feature: "library", state: "title-search-hit", origin: "explicit-original-fixture-URLProtocol")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Explicit fixture".count)); search.typeText("zzzzunfindable")
        XCTAssertTrue(app.staticTexts["没有匹配的完整文章"].waitForExistence(timeout: 10))
        capture("R3-L03", app: app, feature: "library", state: "title-search-no-result", origin: "explicit-original-fixture-URLProtocol")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "zzzzunfindable".count))
        if app.buttons["library-finish-search"].exists { app.buttons["library-finish-search"].tap() }
        else if app.buttons["完成搜索"].exists { app.buttons["完成搜索"].tap() }
        else if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
        else if app.keyboards.buttons["搜索"].exists { app.keyboards.buttons["搜索"].tap() }
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() } else if app.buttons["取消"].exists { app.buttons["取消"].tap() }
        let keyboardGone = NSPredicate(format: "exists == false")
        expectation(for: keyboardGone, evaluatedWith: app.keyboards.firstMatch); waitForExpectations(timeout: 10)
        let favorite = app.buttons["收藏"]
        for _ in 0..<6 { if favorite.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(favorite.isHittable); favorite.tap()
        app.buttons["稍后阅读"].tap()
        XCTAssertTrue(app.buttons["取消收藏"].exists); XCTAssertTrue(app.buttons["移出稍后阅读"].exists)
        capture("R3-L04", app: app, feature: "library", state: "favorite-and-later-saved", origin: "explicit-original-fixture-URLProtocol")
        app.terminate(); app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = "round3-import-offline"; app.launch()
        openLibrary(app)
        XCTAssertTrue(app.buttons["取消收藏"].waitForExistence(timeout: 10)); XCTAssertTrue(app.buttons["移出稍后阅读"].exists)
        capture("R3-L05", app: app, feature: "library", state: "restart-retains-flags-network-unavailable", origin: "URLProtocol-offline-original-fixture")
        app.buttons["发现完整文章"].tap()
        XCTAssertTrue(app.staticTexts["无法导入完整文章，未添加到本地文章库。"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'")).count, 1)
        capture("R3-L06", app: app, feature: "library", state: "refresh-failed-existing-complete-local-version-preserved", origin: "URLProtocol-offline-original-fixture")
        let local = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'")).firstMatch
        for _ in 0..<6 { if local.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(local.isHittable); local.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'word-'")).firstMatch.waitForExistence(timeout: 10))
        capture("R3-R05", app: app, feature: "reader", state: "local-fulltext-with-failing-network", origin: "URLProtocol-offline-original-fixture")
    }
    func testLargeDynamicTypeThreeThemesRemainReadableInLandscape() throws {
        let app = XCUIApplication(); app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = "gallery-reader"; app.launchEnvironment["LEXIDAWN_UI_STORE_ID"] = UUID().uuidString
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]; app.launch()
        let open = app.buttons["open-reader"]; XCTAssertTrue(open.waitForExistence(timeout: 15)); open.tap()
        let navigation = app.navigationBars["英文阅读"]
        if !navigation.waitForExistence(timeout: 4), open.isHittable { open.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        XCTAssertTrue(navigation.waitForExistence(timeout: 10))
        for (theme, title, id) in [("light", "浅色", "R3-R06"), ("dark", "深色", "R3-R07"), ("paper", "暖纸色", "R3-R08")] {
            XCUIDevice.shared.orientation = .portrait
            let appearance = app.buttons["阅读外观"].firstMatch; XCTAssertTrue(appearance.waitForExistence(timeout: 10)); appearance.tap(); app.buttons[title].tap()
            XCUIDevice.shared.orientation = .landscapeLeft
            let word = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'word-'")).firstMatch
            XCTAssertTrue(word.waitForExistence(timeout: 10)); XCTAssertTrue(word.isHittable)
            capture(id, app: app, feature: "reader", state: "maximum-type-landscape-" + theme, theme: theme)
        }
    }
    func testRealLongArticleScrollMemoryAndClockMetrics() throws {
        let app = launch("gallery-reader")
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
        let body = app.otherElements["reader-body"].firstMatch; XCTAssertTrue(body.waitForExistence(timeout: 10))
        let options = XCTMeasureOptions(); options.iterationCount = 3
        measure(metrics: [XCTMemoryMetric(application: app), XCTClockMetric()], options: options) {
            for _ in 0..<4 { body.swipeUp() }
            for _ in 0..<4 { body.swipeDown() }
        }
        XCTAssertTrue(visibleWord(in: app).isHittable)
        capture("R3-P01", app: app, feature: "performance", state: "real-rfc-long-scroll-measured-no-fps-claim")
    }
    func testMatchingEquivalentAccessibilityActionsAndLabels() throws {
        let app = launch("gallery-round3-review"); app.tabBars.buttons["复习"].tap()
        let word = app.buttons["match-word-internet"]; XCTAssertTrue(word.waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: [.sufficientElementDescription])
        word.tap(); XCTAssertEqual(word.value as? String, "已选择")
        capture("R3-M09", app: app, feature: "matching", state: "accessibility-selected-equivalent-action")
        let meaning = app.buttons["match-meaning-互联网（个人释义）"]; meaning.tap()
        XCTAssertEqual(word.value as? String, "已配对"); XCTAssertEqual(meaning.value as? String, "已配对")
        XCTAssertFalse(word.isEnabled); XCTAssertFalse(meaning.isEnabled)
        capture("R3-M10", app: app, feature: "matching", state: "accessibility-completed-both-ends-disabled")
    }
    func testNestedDictionaryWordKeepsDictionaryEvidenceInVocabulary() throws {
        let app = launch("round3-dictionary-single-failed")
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
        let word = app.buttons["word-Internet"].firstMatch; XCTAssertTrue(word.waitForExistence(timeout: 10)); word.tap()
        let detail = app.buttons["查看详细释义"]; XCTAssertTrue(detail.waitForExistence(timeout: 10))
        for _ in 0..<15 { if detail.isEnabled { break }; _ = app.staticTexts["dictionary-providers"].waitForExistence(timeout: 1) }
        XCTAssertTrue(detail.isEnabled); detail.tap()
        let nested = app.links["networks"].firstMatch
        for _ in 0..<12 { if nested.exists && nested.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(nested.isHittable); nested.tap()
        XCTAssertTrue(app.staticTexts["标准词形：network"].waitForExistence(timeout: 10))
        capture("R3-D66", app: app, feature: "dictionary-context", state: "nested-word-from-provider-definition", origin: "explicit-original-provider-fixture-not-production-network")
        XCTAssertEqual(app.buttons.matching(identifier: "close-word").count, 1)
        app.buttons["close-word"].tap(); XCTAssertTrue(app.navigationBars["详细释义"].waitForExistence(timeout: 10))
        app.navigationBars.buttons["查词"].tap(); app.buttons["close-word"].tap(); app.buttons["返回今日"].tap()
        app.tabBars.buttons["词汇"].tap()
        let entry = app.buttons["vocabulary-entry-network"]
        for _ in 0..<6 { if entry.exists && entry.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(entry.isHittable); entry.tap()
        let provenance = app.staticTexts["词典释义：internet"]
        for _ in 0..<12 { if provenance.exists && provenance.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(provenance.isHittable)
        capture("R3-D67", app: app, feature: "vocabulary-context", state: "dictionary-context-retains-real-provider-evidence-separate-from-associated-article", origin: "explicit-original-provider-fixture-real-Repository-context")
    }
    func testSynonymComparisonHasOriginalDefinitionsLoadingEmptyFailureAndSafeRetry() throws {
        for (index, mode) in ["loading", "empty", "failed", "retry"].enumerated() {
            let app = launch("round3-dictionary-comparison-" + mode)
            XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
            let word = app.buttons["word-Internet"].firstMatch; XCTAssertTrue(word.waitForExistence(timeout: 10)); word.tap()
            let detail = app.buttons["查看详细释义"]; XCTAssertTrue(detail.waitForExistence(timeout: 10))
            for _ in 0..<15 { if detail.isEnabled { break }; _ = app.staticTexts["dictionary-providers"].waitForExistence(timeout: 1) }
            XCTAssertTrue(detail.isEnabled); detail.tap()
            let synonyms = app.buttons["dictionary-synonym-comparison"]
            for _ in 0..<5 { if synonyms.exists && synonyms.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(synonyms.isHittable); synonyms.tap()
            let link = app.buttons["dictionary-compare-network"]; XCTAssertTrue(link.waitForExistence(timeout: 10)); link.tap()
            XCTAssertTrue(app.navigationBars["同义词对照"].waitForExistence(timeout: 10))
            if mode == "loading" { XCTAssertTrue(app.descendants(matching: .any)["dictionary-comparison-loading"].waitForExistence(timeout: 5)) }
            else if mode == "empty" { XCTAssertTrue(app.staticTexts["dictionary-comparison-empty"].waitForExistence(timeout: 10)) }
            else { XCTAssertTrue(app.buttons["dictionary-comparison-retry"].waitForExistence(timeout: 10)) }
            capture("R3-D\(50 + index)", app: app, feature: "dictionary-comparison", state: mode, origin: "explicit-original-provider-fixture-not-production-network")
            if mode == "retry" {
                app.buttons["dictionary-comparison-retry"].tap()
                let definition = app.staticTexts["Explicit original comparison fixture: connected elements in a system."]
                XCTAssertTrue(definition.waitForExistence(timeout: 10)); XCTAssertFalse(app.buttons["dictionary-comparison-retry"].exists)
                capture("R3-D54", app: app, feature: "dictionary-comparison", state: "retry-success-with-original-provider-definition", origin: "explicit-original-provider-fixture-not-production-network")
            }
        }
    }
    func testDictionaryProviderFailureEmptyLoadingAndOfflineCacheEvidence() throws {
        for (index, mode) in ["loading", "single-failed", "all-failed", "empty", "cache", "offline"].enumerated() {
            let app = launch("round3-dictionary-" + mode)
            XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
            let word = app.buttons["word-Internet"].firstMatch; XCTAssertTrue(word.waitForExistence(timeout: 10)); word.tap()
            XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10))
            if mode == "loading" {
                let indicator = app.descendants(matching: .any)["dictionary-loading"].firstMatch
                XCTAssertTrue(indicator.waitForExistence(timeout: 5)); XCTAssertTrue(indicator.isHittable)
            }
            else if mode == "all-failed" { XCTAssertTrue(app.staticTexts["词典来源暂时不可用；本地没有缓存，请联网后重试。"].waitForExistence(timeout: 15)) }
            else if mode == "empty" { XCTAssertTrue(app.staticTexts["暂无可验证的释义。可以继续阅读，或在生词本添加明确标记的个人释义。"].waitForExistence(timeout: 15)) }
            else {
                let providers = app.staticTexts["dictionary-providers"]
                for _ in 0..<5 { if providers.exists { break }; app.swipeUp() }
                XCTAssertTrue(providers.waitForExistence(timeout: 15))
                let detail = app.buttons["查看详细释义"]
                for _ in 0..<5 { if detail.isHittable { break }; app.swipeUp() }
                XCTAssertTrue(detail.waitForExistence(timeout: 15)); detail.tap()
                let expected = mode == "single-failed" ? "部分来源不可用" : mode == "cache" || mode == "offline" ? "本地缓存" : "已合并"
                let label = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", expected)).firstMatch
                for _ in 0..<6 { if label.exists && label.isHittable { break }; app.swipeUp() }
                XCTAssertTrue(label.waitForExistence(timeout: 15))
            }
            capture("R3-D" + String(format: "%02d", index + 1), app: app, feature: "dictionary", state: mode, origin: "explicit-original-provider-fixture-not-production-network")
            app.terminate()
        }
    }
    func testLiveMultipleSourcesLibraryFiltersAndCompleteLocalReaderEvidence() throws {
        let app = launch("round3-network-all"); openLibrary(app)
        app.buttons["发现完整文章"].tap()
        XCTAssertTrue(app.staticTexts["article-notice"].waitForExistence(timeout: 240), "Real publisher discovery must complete; no seeded articles")
        capture("R3-S00", app: app, feature: "article", state: "live-multiple-source-import-library", origin: "production-network-empty-isolated-store")
        // Unlock through actual app actions, never by inserting completed cycles or review evidence.
        app.navigationBars.buttons.firstMatch.tap()
        let sourceCards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'today-source-'"))
        for _ in 0..<12 { if sourceCards.firstMatch.exists && sourceCards.firstMatch.isHittable { break }; app.swipeUp() }
        XCTAssertGreaterThanOrEqual(sourceCards.count, 2); XCTAssertTrue(sourceCards.firstMatch.isHittable)
        capture("R3-S01", app: app, feature: "today", state: "diverse-source-complete-originals-homepage", origin: "production-network-empty-isolated-store")
        let task = app.buttons["open-reader"]
        for _ in 0..<15 { if task.exists && task.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(task.waitForExistence(timeout: 10)); XCTAssertTrue(task.isHittable); task.tap()
        XCTAssertTrue(app.buttons["finish-reading"].waitForExistence(timeout: 10)); app.buttons["finish-reading"].tap()
        if app.alerts.buttons["确认我已读完"].waitForExistence(timeout: 2) { app.alerts.buttons["确认我已读完"].tap() }
        XCTAssertTrue(app.staticTexts["reading-completed"].waitForExistence(timeout: 10)); app.buttons["返回今日"].tap()
        app.tabBars.buttons["复习"].tap()
        XCTAssertTrue(app.staticTexts["完整队列中没有应复习词条，已记录合法空队列结果。"].waitForExistence(timeout: 10))
        app.tabBars.buttons["今日"].tap(); XCTAssertTrue(app.staticTexts["cycle-completed"].waitForExistence(timeout: 10)); openLibrary(app)
        let sources = [("wikipedia", "Wikipedia"), ("wikinews", "Wikinews"), ("bbc", "BBC News"), ("reuters", "Reuters"), ("ap", "AP News"), ("guardian", "The Guardian"), ("npr", "NPR"), ("dw", "Deutsche Welle"), ("voa", "VOA Learning English"), ("nasa", "NASA"), ("sciencedaily", "ScienceDaily"), ("phys", "Phys.org"), ("smithsonian", "Smithsonian Magazine")]
        var inspected = 0
        for (id, title) in sources {
            let filter = app.buttons["library-source-filter"]
            for _ in 0..<12 { if filter.isHittable { break }; app.swipeDown() }
            XCTAssertTrue(filter.isHittable); filter.tap()
            let choice = app.buttons[title]
            guard choice.exists else {
                let all = app.buttons["全部来源"]; XCTAssertTrue(all.exists); XCTAssertTrue(all.isHittable); all.tap(); continue
            }
            choice.tap()
            let open = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'")).firstMatch
            for _ in 0..<10 { if open.exists && open.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(open.isHittable)
            capture("R3-S-" + id + "-library", app: app, feature: "article", state: "source-filter-" + id, origin: "production-network-empty-isolated-store")
            open.tap()
            XCTAssertTrue(app.navigationBars["英文阅读"].waitForExistence(timeout: 10)); XCTAssertTrue(visibleWord(in: app).isHittable)
            capture("R3-S-" + id + "-body", app: app, feature: "reader", state: "complete-local-first-page-" + id, origin: "production-network-empty-isolated-store")
            let body = app.otherElements["reader-body"].firstMatch
            body.swipeUp(); XCTAssertTrue(visibleWord(in: app).isHittable)
            capture("R3-S-" + id + "-scrolled", app: app, feature: "reader", state: "local-scrolled-page-" + id, origin: "production-network-empty-isolated-store")
            for _ in 0..<80 {
                let progress = Int(app.staticTexts["reader-progress"].label.replacingOccurrences(of: "%", with: "")) ?? 0
                if progress >= 95 { break }; body.swipeUp(velocity: .fast)
            }
            XCTAssertGreaterThanOrEqual(Int(app.staticTexts["reader-progress"].label.replacingOccurrences(of: "%", with: "")) ?? 0, 95)
            XCTAssertTrue(visibleWord(in: app).isHittable)
            capture("R3-S-" + id + "-end", app: app, feature: "reader", state: "local-end-at-least-95-percent-" + id, origin: "production-network-empty-isolated-store")
            app.buttons["关闭文章"].tap(); inspected += 1
        }
        XCTAssertGreaterThanOrEqual(inspected, 5, "At least five real imported source readers must be inspected")
    }
    func testVocabularySaveFailureDoesNotClaimSuccessAndRetryPersists() throws {
        let app = launch("round3-storage-vocabulary")
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["word-Internet"].firstMatch.waitForExistence(timeout: 10)); app.buttons["word-Internet"].firstMatch.tap()
        let error = app.staticTexts["明确故障注入：数据库保存失败，未加入生词本。"]
        XCTAssertTrue(error.waitForExistence(timeout: 10)); XCTAssertFalse(app.buttons["undo-word"].exists)
        capture("R3-V01", app: app, feature: "vocabulary", state: "save-failed-no-success", origin: "explicit-one-shot-Repository-save-fault-bundled-RFC")
        app.buttons["重试保存生词"].tap()
        let undo = app.buttons["undo-word"]
        for _ in 0..<5 { if undo.exists && undo.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(undo.waitForExistence(timeout: 10)); XCTAssertTrue(undo.isHittable); XCTAssertFalse(error.exists)
        capture("R3-V02", app: app, feature: "vocabulary", state: "safe-retry-save-success", origin: "explicit-one-shot-Repository-save-fault-bundled-RFC")
        app.buttons["close-word"].tap(); app.buttons["返回今日"].tap(); app.tabBars.buttons["词汇"].tap()
        XCTAssertTrue(app.buttons["vocabulary-entry-internet"].waitForExistence(timeout: 10))
        capture("R3-V03", app: app, feature: "vocabulary", state: "retry-result-in-persistent-notebook", origin: "explicit-one-shot-Repository-save-fault-bundled-RFC")
    }
    func testArticleLoadingCanCancelWithoutLeavingCandidateRecords() throws {
        let app = launch("round3-import-loading"); openLibrary(app); app.buttons["发现完整文章"].tap()
        let stop = app.buttons["cancel-article-discovery"]; XCTAssertTrue(stop.waitForExistence(timeout: 5))
        capture("R3-A20", app: app, feature: "article", state: "fulltext-discovery-loading", origin: "explicit-delayed-URLProtocol-fixture")
        stop.tap()
        XCTAssertTrue(app.staticTexts["已停止发现；已完整入库的文章保留。"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'")).count, 0)
        capture("R3-A21", app: app, feature: "article", state: "cancelled-no-candidate-record", origin: "explicit-delayed-URLProtocol-fixture")
    }
    func testComplexFormsAndFourContextPhrasesUseNestedLookupAndReturn() throws {
        let app = launch("round3-phrases")
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
        for (index, surface, lemma, phrase) in [(0,"took","take",""),(1,"taken","take",""),(2,"look","look","look into"),(3,"carry","carry","carry out"),(4,"account","account","take into account"),(5,"role","role","play a role in")] {
            let word = app.buttons["word-" + surface].firstMatch
            for _ in 0..<8 { if word.exists && word.isHittable { break }; app.otherElements["reader-body"].firstMatch.swipeUp() }
            XCTAssertTrue(word.isHittable); word.tap()
            XCTAssertTrue(app.staticTexts["标准词形：" + lemma].waitForExistence(timeout: 10))
            capture("R3-D" + String(index + 10), app: app, feature: "dictionary", state: "surface-" + surface, origin: "explicit-original-context-fixture-local-real-CEDICT")
            if !phrase.isEmpty {
                XCTAssertTrue(app.buttons[phrase].waitForExistence(timeout: 10)); app.buttons[phrase].tap()
                XCTAssertTrue(app.staticTexts["标准词形：" + phrase].waitForExistence(timeout: 10))
                capture("R3-D" + String(index + 20), app: app, feature: "dictionary", state: "nested-phrase-" + phrase, origin: "explicit-original-context-fixture-local-real-CEDICT")
                app.buttons["close-word"].firstMatch.tap()
                XCTAssertTrue(app.staticTexts["标准词形：" + lemma].waitForExistence(timeout: 10))
                capture("R3-D" + String(index + 60), app: app, feature: "dictionary", state: "returned-from-nested-phrase-" + phrase, origin: "explicit-original-context-fixture-local-real-CEDICT")
            }
            app.buttons["close-word"].firstMatch.tap(); XCTAssertTrue(app.otherElements["reader-body"].firstMatch.waitForExistence(timeout: 10))
        }
    }
    func testReaderThemeExtendsToDictionaryPresentation() throws {
        let app = launch("gallery-reader"); XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
        for (index, title, theme) in [(0,"浅色","light"),(1,"深色","dark"),(2,"暖纸色","paper")] {
            app.buttons["阅读外观"].firstMatch.tap(); app.buttons[title].tap()
            let word = app.buttons["word-Internet"].firstMatch; XCTAssertTrue(word.waitForExistence(timeout: 10)); word.tap()
            XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10))
            capture("R3-D" + String(index + 30), app: app, feature: "dictionary", state: "reader-popup-theme-" + theme, theme: theme, origin: "real-bundled-RFC-local-real-CEDICT")
            app.buttons["close-word"].tap()
            app.buttons["来源详情"].firstMatch.tap()
            XCTAssertTrue(app.navigationBars["来源详情"].waitForExistence(timeout: 10))
            capture("R3-D" + String(index + 33), app: app, feature: "reader-source", state: "reader-source-sheet-theme-" + theme, theme: theme, origin: "real-bundled-RFC-source-metadata")
            app.buttons["close-source-details"].tap()
        }
    }
    func testReviewAnswerSaveFailureKeepsBothOptionsAvailableAndRetryPersistsOnce() throws {
        let app = launch("gallery-review-save-failure"); app.tabBars.buttons["复习"].tap()
        let word = app.buttons["match-word-internet"], meaning = app.buttons["match-meaning-互联网（个人释义）"]
        XCTAssertTrue(word.waitForExistence(timeout: 15)); word.tap(); meaning.tap()
        let error = app.staticTexts["review-storage-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10)); XCTAssertTrue(word.isEnabled); XCTAssertTrue(meaning.isEnabled)
        XCTAssertNotEqual(word.value as? String, "已配对"); XCTAssertFalse(app.staticTexts["正确，已保存"].exists)
        capture("R3-G10", app: app, feature: "review-storage", state: "actual-answer-transaction-failed-without-completed-options", origin: "explicit-save-fault-real-Repository-question-and-cycle")
        word.tap(); meaning.tap()
        XCTAssertEqual(word.value as? String, "已配对"); XCTAssertFalse(word.isEnabled); XCTAssertFalse(meaning.isEnabled)
        XCTAssertFalse(error.exists)
        capture("R3-G11", app: app, feature: "review-storage", state: "retry-saved-correct-pair-once", origin: "explicit-save-fault-real-Repository-question-and-cycle")
        app.terminate(); app.launch(); app.tabBars.buttons["复习"].tap()
        XCTAssertTrue(word.waitForExistence(timeout: 15)); XCTAssertFalse(word.isEnabled); XCTAssertFalse(meaning.isEnabled)
        capture("R3-G12", app: app, feature: "review-storage", state: "process-restart-restores-only-committed-answer", origin: "explicit-save-fault-real-Repository-question-and-cycle")
    }
    func testHardAndGoodFeedbackPersistScheduleChangesAcrossRestart() throws {
        let app = launch("gallery-round3-review"); app.tabBars.buttons["复习"].tap()
        XCTAssertTrue(app.buttons["match-word-internet"].waitForExistence(timeout: 15))
        app.buttons["match-word-internet"].tap(); app.buttons["match-meaning-文档（个人释义）"].tap()
        XCTAssertTrue(app.staticTexts["review-feedback"].label.contains("还不正确"))
        for (word, meaning) in [("internet","互联网（个人释义）"),("document","文档（个人释义）"),("book","书（个人释义）")] {
            app.buttons["match-word-" + word].tap(); app.buttons["match-meaning-" + meaning].tap()
        }
        for word in ["internet", "document", "book"] {
            let field = app.textFields["cloze-answer"]; XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText(word)
            app.buttons["submit-spelling"].tap()
        }
        XCTAssertTrue(app.staticTexts["本次复习已保存"].waitForExistence(timeout: 10))
        let hard = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Hard' AND label CONTAINS '原定' AND label CONTAINS '下次复习'")).firstMatch
        let good = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Good' AND label CONTAINS '原定' AND label CONTAINS '下次复习'")).firstMatch
        XCTAssertTrue(hard.waitForExistence(timeout: 10)); XCTAssertTrue(good.exists)
        capture("R3-G01", app: app, feature: "review", state: "hard-good-original-and-next-due", origin: "explicit-review-seed-real-RFC-and-personal-meanings")
        app.terminate(); app.launch(); app.tabBars.buttons["复习"].tap()
        XCTAssertTrue(hard.waitForExistence(timeout: 10)); XCTAssertTrue(good.exists)
        capture("R3-G02", app: app, feature: "review", state: "persisted-grade-and-schedule-after-restart", origin: "explicit-review-seed-real-RFC-and-personal-meanings")
    }
    func testNoteSaveFailurePreservesDraftAndNeverLeavesOldSuccessLabel() throws {
        let app = launch("round3-storage-note")
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["word-Internet"].firstMatch.waitForExistence(timeout: 10)); app.buttons["word-Internet"].firstMatch.tap()
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10)); app.buttons["close-word"].tap(); app.buttons["返回今日"].tap(); app.tabBars.buttons["词汇"].tap()
        let entry = app.buttons["vocabulary-entry-internet"]; XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        let meaning = app.textFields["personal-meaning"]; XCTAssertTrue(meaning.waitForExistence(timeout: 10)); meaning.tap(); meaning.typeText("明确的个人释义")
        app.buttons["保存个人释义与笔记"].tap(); XCTAssertTrue(app.staticTexts["已保存"].waitForExistence(timeout: 10))
        capture("R3-V04", app: app, feature: "vocabulary", state: "initial-personal-meaning-save-success", origin: "explicit-Repository-third-save-fault-original-note-draft")
        let notes = app.descendants(matching: .any)["vocabulary-notes"].firstMatch
        XCTAssertTrue(notes.exists); notes.tap(); notes.typeText("Second note draft")
        if app.buttons["完成输入"].exists { app.buttons["完成输入"].tap() }
        XCTAssertFalse(app.staticTexts["已保存"].exists); app.buttons["保存个人释义与笔记"].tap()
        XCTAssertTrue(app.staticTexts["明确故障注入：释义与笔记保存失败，草稿已保留。"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["已保存"].exists); XCTAssertTrue((notes.value as? String)?.contains("Second note draft") == true)
        capture("R3-V05", app: app, feature: "vocabulary", state: "note-save-failed-draft-kept-no-stale-success", origin: "explicit-Repository-third-save-fault-original-note-draft")
        app.buttons["重试保存释义与笔记"].tap(); XCTAssertTrue(app.staticTexts["已保存"].waitForExistence(timeout: 10))
        capture("R3-V06", app: app, feature: "vocabulary", state: "note-safe-retry-success", origin: "explicit-Repository-third-save-fault-original-note-draft")
        app.terminate(); app.launch(); app.tabBars.buttons["词汇"].tap(); XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        let persisted = NSPredicate(format: "value CONTAINS %@", "Second note draft")
        expectation(for: persisted, evaluatedWith: notes); waitForExpectations(timeout: 10)
        capture("R3-V07", app: app, feature: "vocabulary", state: "note-retry-result-after-process-restart", origin: "explicit-Repository-third-save-fault-original-note-draft")
    }
    /// Scrolling can retain offscreen accessibility elements. Exercise a word in the visible viewport.
    private func visibleWord(in app: XCUIApplication) -> XCUIElement {
        let words = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'word-'"))
        let token = words.allElementsBoundByIndex.first { $0.isHittable && app.windows.firstMatch.frame.intersects($0.frame) }
        XCTAssertNotNil(token, "The scrolled reader must expose a real, visible, tappable word")
        return token ?? words.firstMatch
    }
    /// Sample only the middle of the board's gap. Button text/icons cannot satisfy this assertion.
    private func greenLinePixels(app: XCUIApplication) -> Int {
        let board = app.otherElements["matching-board"].firstMatch
        guard board.waitForExistence(timeout: 5) else { return 0 }
        let screenshot = XCUIScreen.main.screenshot()
        guard let source = CGImageSourceCreateWithData(screenshot.pngRepresentation as CFData, nil),
              let raw = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: max(raw.width, raw.height)] as CFDictionary) else { return 0 }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        let screen = app.windows.firstMatch.frame
        print("Native screenshot geometry: window=\(screen), board=\(board.frame), pixels=\(width)x\(height), deviceOrientation=\(XCUIDevice.shared.orientation.rawValue)")
        let sx = Double(width) / Double(screen.width), sy = Double(height) / Double(screen.height)
        let middle = Int(Double(board.frame.midX) * sx), top = max(0, Int(Double(board.frame.minY) * sy)), bottom = min(height, Int(Double(board.frame.maxY) * sy))
        guard top < bottom, middle > 4, middle < width - 4 else { return 0 }
        var count = 0
        for y in top..<bottom { for x in (middle - 3)...(middle + 3) {
            let i = (y * width + x) * 4
            if Int(bytes[i + 1]) > Int(bytes[i]) + 25 && Int(bytes[i + 1]) > Int(bytes[i + 2]) + 15 { count += 1 }
        } }
        return count
    }
}
