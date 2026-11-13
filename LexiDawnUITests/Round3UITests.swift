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
        if name.contains("testImportRetryDedupSearchFavoritesAndLocalRestart"), (testRun?.failureCount ?? 0) > 0 {
            let app = XCUIApplication()
            let attachment = XCTAttachment(string: app.debugDescription)
            attachment.name = "round3-library-failure-hierarchy"; attachment.lifetime = .keepAlways; add(attachment)
            capture("R3-library-retry-diagnostic", app: app, feature: "article", state: "failed-test-native-library-state", origin: "explicit-original-fixture-URLProtocol")
        }
        if name.contains("testLiveMultipleSourcesLibraryFiltersAndCompleteLocalReaderEvidence"), (testRun?.failureCount ?? 0) > 0 {
            let app = XCUIApplication()
            let attachment = XCTAttachment(string: app.debugDescription)
            attachment.name = "round3-live-library-failure-hierarchy"
            attachment.lifetime = .keepAlways
            add(attachment)
            capture("R3-live-library-diagnostic", app: app, feature: "article", state: "live-source-test-failed", origin: "production-network-empty-isolated-store")
        }
    }
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication(); app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = scenario
        app.launchEnvironment["LEXIDAWN_UI_STORE_ID"] = UUID().uuidString; app.launch(); return app
    }
    private func choose(_ identifier: String, option: String, app: XCUIApplication) throws {
        if identifier == "library-mode-filter" {
            let scopes = app.segmentedControls[identifier]
            for _ in 0..<7 { if scopes.isHittable { break }; app.swipeDown() }
            XCTAssertTrue(scopes.isHittable)
            let title = option == "稍后阅读" ? "稍后" : option
            let segment = scopes.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", title, title + " ")).firstMatch
            XCTAssertTrue(segment.isHittable); segment.tap()
            return
        }
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
        XCTAssertTrue(app.buttons["word-JavaScript"].firstMatch.exists)
        XCTAssertFalse(app.buttons["word-enable"].firstMatch.exists)
        capture("R4-P07-cleaned-structure", app: app, feature: "reader", state: "structured-quotation-retained-player-controls-discarded", origin: "explicit-original-HTML-through-real-extractor-and-Repository")
        capture("R3-R10", app: app, feature: "reader", state: "structured-original-headings-and-quotation", origin: "explicit-original-HTML-through-real-extractor-and-Repository")
        let listItem = app.buttons["word-First"].firstMatch
        for _ in 0..<6 {
            if listItem.exists && listItem.isHittable { break }
            let start = body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        XCTAssertTrue(listItem.isHittable)
        capture("R3-R11", app: app, feature: "reader", state: "original-list-and-natural-paragraphs", origin: "explicit-original-HTML-through-real-extractor-and-Repository")

        app.terminate()
        let legacy = launch("round3-reader-legacy-dw")
        XCTAssertTrue(legacy.buttons["open-reader"].waitForExistence(timeout: 15)); legacy.buttons["open-reader"].tap()
        XCTAssertTrue(legacy.buttons["word-preceding"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(legacy.buttons["word-following"].firstMatch.isHittable)
        XCTAssertTrue(legacy.buttons["word-JavaScript"].firstMatch.exists)
        XCTAssertFalse(legacy.buttons["word-upgrading"].firstMatch.exists)
        capture("R4-P07-legacy-dw-projection", app: legacy, feature: "reader", state: "prior-source-player-paragraph-hidden-with-actual-adjacent-paragraphs", origin: "explicit-original-disk-fixture-production-DW-display-projection")
    }
    func testPersonalOriginalUpdateFormAndChangedVersionRestoreNativeReader() throws {
        let app = launch("round3-version-change"); openLibrary(app)
        let edit = app.buttons["更新个人原文"].firstMatch
        for _ in 0..<7 { if edit.exists && edit.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(edit.isHittable); edit.tap(); XCTAssertTrue(app.navigationBars["更新个人原文"].waitForExistence(timeout: 10))
        let title = app.textFields["import-title"]; XCTAssertTrue(title.exists); title.tap(); title.typeText(" verified")
        let done = app.buttons["finish-article-input"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        let form = app.collectionViews["article-import-form"]
        XCTAssertTrue(form.exists)
        let rights = app.switches["import-rights"]
        for _ in 0..<7 { if rights.exists && rights.isHittable { break }; form.swipeUp() }
        XCTAssertTrue(rights.isHittable); let toggle = rights.switches.firstMatch; if toggle.exists { toggle.tap() } else { rights.tap() }
        capture("R3-R12", app: app, feature: "reader-version", state: "explicit-owned-original-update-confirmation", origin: "explicit-original-version-fixture-real-Repository-update")
        let save = app.buttons["save-import"]
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
        let app = launch("round4-rich"); app.buttons["open-reader"].tap(); app.buttons["word-nod"].firstMatch.tap(); XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10)); app.buttons["close-word"].tap(); app.buttons["返回今日"].tap(); app.tabBars.buttons["词汇"].tap()
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
        XCTAssertTrue(app.buttons["choose-review-meaning"].label.contains("学习义项："))
        capture("R3-V12", app: app, feature: "vocabulary", state: "explicit-source-meaning-saved", origin: "explicit-original-MDX-layout-fixture-with-explicit-user-selection")
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
                let cancel = app.buttons["cancel-vocabulary-export"]
                XCTAssertTrue(cancel.isHittable)
                XCTAssertGreaterThanOrEqual(cancel.frame.height, 44)
                cancel.tap()
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
        if app.state == .runningForeground { _ = app.windows.firstMatch.frame; _ = app.descendants(matching: .any).count }
        let device = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? UIDevice.current.name
        let identifier = id + "-" + device.map { $0.isLetter || $0.isNumber || $0 == "-" ? String($0) : "-" }.joined()
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = identifier; image.lifetime = .keepAlways; add(image)
        let metadata: [String: String] = ["screenshotID": identifier, "featureID": feature, "screenName": feature, "state": state,
            "device": ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? UIDevice.current.name, "orientation": XCUIDevice.shared.orientation.isLandscape ? "landscape" : "portrait", "theme": theme,
            "osVersion": UIDevice.current.systemVersion, "fontSize": nativeEvidenceFontSize(app),
            "testName": name, "fixtureOrProduction": origin, "fileName": identifier + ".png", "notes": "Native Simulator screenshot; no image generation."]
        do {
            let data = try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
            let json = XCTAttachment(data: data, uniformTypeIdentifier: "public.json"); json.name = identifier + "-metadata"; json.lifetime = .keepAlways; add(json)
        } catch { XCTFail("Cannot encode native screenshot metadata: \(error)") }
    }
    func testHistoricalFavoriteLaterAndHistoryStayLockedUntilCurrentTaskFinishes() throws {
        let app = launch("round3-history-gate"); openLibrary(app)
        let historical = app.buttons["library-open-rfc-editor-8890"]
        for _ in 0..<5 { if historical.exists { break }; app.swipeUp() }
        XCTAssertTrue(historical.waitForExistence(timeout: 10)); XCTAssertFalse(historical.isEnabled)
        capture("R3-LOCK01", app: app, feature: "article-gate", state: "historical-daily-article-locked", origin: "explicit-historical-cycle-fixture-real-domain-evidence")
        for (index, filter) in ["收藏", "稍后阅读", "历史"].enumerated() {
            try choose("library-mode-filter", option: filter, app: app)
            for _ in 0..<5 { if historical.exists && historical.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(historical.exists); XCTAssertFalse(historical.isEnabled)
            capture("R3-LOCK0\(index + 2)", app: app, feature: "article-gate", state: filter + "-cannot-open-old-daily-article", origin: "explicit-historical-cycle-fixture-real-domain-evidence")
        }
    }
    func testQuickMeaningIsBoundedAndFullScreenDetailKeepsAllSenses() throws {
        let app = launch("round3-dictionary-many")
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["word-Internet"].firstMatch.waitForExistence(timeout: 10)); app.buttons["word-Internet"].firstMatch.tap()
        let quick = app.descendants(matching: .any)["compact-word-card"].firstMatch
            .descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'dictionary-quick-sense-'"))
        XCTAssertTrue(quick.firstMatch.waitForExistence(timeout: 15)); XCTAssertEqual(quick.count, 2)
        XCTAssertFalse(app.staticTexts["原创测试义项 6"].exists)
        capture("R3-D40", app: app, feature: "dictionary", state: "bounded-two-sense-quick-meaning", origin: "explicit-original-six-sense-provider-fixture")
        app.buttons["dictionary-details"].tap(); XCTAssertTrue(app.buttons["关闭详细释义"].waitForExistence(timeout: 10))
        let last = app.staticTexts["原创测试义项 6"].firstMatch
        for _ in 0..<10 { if last.exists && last.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(last.exists); XCTAssertTrue(last.isHittable)
        capture("R3-D41", app: app, feature: "dictionary", state: "full-screen-all-six-senses-grouped-by-pos", origin: "explicit-original-six-sense-provider-fixture")
        app.buttons["返回查词"].tap(); XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10))
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
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recommendation-detail-'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        capture("R3-N02", app: app, feature: "word-recommendation", state: "real-article-candidates-with-explicit-fixture-definitions", origin: "explicit-original-article-and-provider-fixture")
        card.tap(); XCTAssertTrue(app.buttons["关闭详细释义"].waitForExistence(timeout: 10)); XCTAssertTrue(app.buttons["add-word"].exists)
        capture("R3-N03", app: app, feature: "word-recommendation", state: "detail-does-not-auto-add", origin: "explicit-original-article-and-provider-fixture")
        app.buttons["关闭详细释义"].tap(); XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        XCTAssertTrue(app.buttons["add-word"].waitForExistence(timeout: 10)); app.buttons["add-word"].tap()
        XCTAssertTrue(app.staticTexts["已加入生词本"].waitForExistence(timeout: 10))
        capture("R3-N04", app: app, feature: "word-recommendation", state: "explicit-add-persisted", origin: "explicit-original-article-and-provider-fixture")
        app.buttons["关闭详细释义"].tap(); app.navigationBars.buttons["生词本"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vocabulary-entry-'")).count, 1)
        app.terminate()
        app = launch("round3-explore-catalog")
        app.tabBars.buttons["词汇"].tap(); app.buttons["vocabulary-recommendations"].tap()
        let recommendation = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recommendation-detail-'")).firstMatch
        XCTAssertTrue(recommendation.waitForExistence(timeout: 30))
        let chinese = try NSRegularExpression(pattern: #"\p{Han}"#)
        let label = recommendation.label
        XCTAssertNotNil(chinese.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)))
        capture("R4-P17-actual-recommendations", app: app, feature: "word-recommendation", state: "local-article-candidates-with-real-MDX-meanings", origin: "real-bundled-MDX-with-explicit-original-articles")
        recommendation.tap()
        XCTAssertTrue(app.buttons["add-word"].waitForExistence(timeout: 10))
        capture("R4-P15-recommendation-detail", app: app, feature: "dictionary-detail", state: "shared-native-detail-from-real-MDX-recommendation", origin: "real-bundled-MDX-with-explicit-original-articles")
        app.buttons["关闭详细释义"].tap(); app.navigationBars.buttons["生词本"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vocabulary-entry-'")).count, 0)
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
        if internet.value as? String != "已选择" { internet.tap() }; app.buttons["match-meaning-互联网（个人释义）"].tap()
        XCTAssertFalse(internet.isEnabled); XCTAssertFalse(app.buttons["match-meaning-互联网（个人释义）"].isEnabled)
        XCTAssertGreaterThan(connectionPixels(app: app), 12, "A real rendered line must cross the column gap")
        capture("R3-M04", app: app, feature: "matching", state: "one-visible-line-both-ends-disabled")
        app.buttons["match-word-document"].tap(); app.buttons["match-meaning-文档（个人释义）"].tap()
        XCTAssertGreaterThan(connectionPixels(app: app), 24)
        capture("R3-M05", app: app, feature: "matching", state: "two-visible-lines")
        XCUIDevice.shared.orientation = .landscapeLeft
        let settled = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
        expectation(for: settled, evaluatedWith: app); waitForExpectations(timeout: 10)
        XCTAssertGreaterThan(connectionPixels(app: app), 12)
        capture("R3-M06", app: app, feature: "matching", state: "landscape-lines")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["match-word-book"].tap(); app.buttons["match-meaning-书（个人释义）"].tap()
        XCTAssertTrue(app.textFields["cloze-answer"].waitForExistence(timeout: 10))
        capture("R3-M07", app: app, feature: "review", state: "matching-complete-spelling-context")
        app.buttons["show-completed-matches"].tap()
        for text in ["internet", "document", "book"] { let word = app.buttons["match-word-" + text]; XCTAssertTrue(word.exists); XCTAssertFalse(word.isEnabled) }
        let rendered = NSPredicate { _, _ in self.connectionPixels(app: app) > 24 }
        expectation(for: rendered, evaluatedWith: app); waitForExpectations(timeout: 8)
        capture("R3-M08", app: app, feature: "matching", state: "all-three-completed-connections-retained")
        let board = app.otherElements["matching-board"].firstMatch
        let previousY = board.frame.minY
        let window = app.windows.firstMatch.frame
        let scroll = app.scrollViews["review-scroll"].firstMatch
        XCTAssertTrue(scroll.exists)
        let scrollFrame = scroll.frame
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let travel = min(56, scrollFrame.height / 7)
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -travel)), withVelocity: .slow, thenHoldForDuration: 0.15)
        XCTAssertLessThan(board.frame.minY, previousY)
        XCTAssertGreaterThan(board.frame.maxY, window.minY + 125, "The test must leave the line region on screen")
        XCTAssertGreaterThan(connectionPixels(app: app), 12)
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
        let addSense = app.buttons["添加义项"]
        let official = app.buttons["choose-review-meaning"]
        let meaningReady = NSPredicate { _, _ in addSense.exists || official.exists }
        expectation(for: meaningReady, evaluatedWith: app); waitForExpectations(timeout: 20)
        if addSense.exists {
            for _ in 0..<12 { if addSense.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(addSense.isHittable); addSense.tap()
            let part = app.buttons["personal-part-of-speech"].firstMatch
            for _ in 0..<8 { if part.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(part.isHittable); part.tap(); app.buttons["n. 名词"].tap()
            let meaning = app.textFields["personal-meaning"].firstMatch
            for _ in 0..<8 { if meaning.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(meaning.isHittable); meaning.tap(); meaning.typeText("我对原文词语的个人理解")
            if app.buttons["完成输入"].exists { app.buttons["完成输入"].tap() }
            let confirm = app.switches["确认作为学习义项"].firstMatch
            for _ in 0..<8 { if confirm.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(confirm.isHittable); confirm.tap()
            capture("R3-C03-personal", app: app, feature: "dictionary", state: "actual-MDX-without-Chinese-explicit-personal-review-sense", origin: origin)
        } else {
            for _ in 0..<20 { if official.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(official.isHittable); official.tap()
            let sense = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'review-meaning-'")).firstMatch
            for _ in 0..<10 { if sense.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(sense.isHittable); sense.tap()
            XCTAssertTrue(official.label.contains("学习义项："))
        }
        let notes = app.textFields["vocabulary-notes"]
        for _ in 0..<20 { if notes.exists && notes.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(notes.isHittable); notes.tap(); notes.typeText("真实文章学习笔记")
        if app.buttons["完成输入"].exists { app.buttons["完成输入"].tap() }
        expectation(for: NSPredicate(format: "label == %@", "已自动保存"), evaluatedWith: app.staticTexts["annotation-save-state"]); waitForExpectations(timeout: 10)
        capture("R3-C04", app: app, feature: "vocabulary", state: "actual-MDX-meaning-and-explicit-user-note-saved", origin: "production-article-network-real-bundled-MDX-user-note")
        app.navigationBars.buttons["生词本"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        for _ in 0..<20 { if notes.exists && notes.isHittable { break }; app.swipeUp() }
        XCTAssertEqual(notes.value as? String, "真实文章学习笔记")
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
        app.tabBars.buttons["探索"].tap(); XCTAssertTrue(app.buttons["explore-topic-filter"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["先完成必做，再自由探索"].exists)
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
            app.buttons["library-discover"].tap()
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
        let discover = app.buttons["library-discover"]
        XCTAssertTrue(discover.isHittable); discover.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["article-notice"].waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(app.staticTexts["article-notice"].label.contains("已导入 1"))
        capture("R3-A18", app: app, feature: "article", state: "503-retry-success-full-import", origin: "URLProtocol-retry-with-original-test-text")
        XCTAssertTrue(discover.isHittable); discover.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["article-notice"].waitForExistence(timeout: 10))
        let notice = app.staticTexts["article-notice"]
        let noNew = NSPredicate(format: "label CONTAINS '没有新文章'")
        expectation(for: noNew, evaluatedWith: notice); waitForExpectations(timeout: 15)
        let inventory = app.staticTexts["library-total-count"]
        let filtered = app.staticTexts["library-filtered-count"]
        let list = app.collectionViews["article-library-list"].firstMatch
        let libraryScroll = list.exists ? list : app
        for _ in 0..<5 { if inventory.exists && inventory.isHittable { break }; libraryScroll.swipeUp() }
        XCTAssertTrue(inventory.waitForExistence(timeout: 10))
        XCTAssertEqual(inventory.label, "共 1 篇")
        XCTAssertEqual(filtered.label, "当前 1 篇")
        capture("R3-A19", app: app, feature: "article", state: "deduplicated-no-new-article", origin: "explicit-original-fixture-URLProtocol")
        let search = app.searchFields.firstMatch
        for _ in 0..<4 { if search.exists && search.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 10)); XCTAssertTrue(search.isHittable)
        search.tap(); search.typeText("Explicit fixture")
        let match = app.staticTexts["Explicit fixture article (not production)"]
        XCTAssertTrue(match.waitForExistence(timeout: 10))
        XCTAssertTrue(match.isHittable)
        XCTAssertEqual(filtered.label, "当前 1 篇")
        capture("R3-L02", app: app, feature: "library", state: "title-search-hit", origin: "explicit-original-fixture-URLProtocol")
        XCTAssertTrue(search.isHittable); search.tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Explicit fixture".count)); search.typeText("zzzzunfindable")
        XCTAssertEqual(search.value as? String, "zzzzunfindable")
        let noResults = app.descendants(matching: .any)["library-empty"].firstMatch
        XCTAssertTrue(noResults.waitForExistence(timeout: 10))
        XCTAssertTrue(noResults.isHittable)
        XCTAssertEqual(filtered.label, "当前 0 篇")
        XCTAssertEqual(inventory.label, "共 1 篇")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'")).count, 0)
        capture("R3-L03", app: app, feature: "library", state: "title-search-no-result", origin: "explicit-original-fixture-URLProtocol")
        let closeSearch = app.navigationBars.firstMatch.buttons.matching(
            NSPredicate(format: "label IN %@", ["Close", "Cancel", "关闭", "取消"])
        ).firstMatch
        XCTAssertTrue(closeSearch.isHittable)
        closeSearch.tap()
        let keyboardGone = NSPredicate(format: "exists == false")
        expectation(for: keyboardGone, evaluatedWith: app.keyboards.firstMatch); waitForExpectations(timeout: 10)
        let favorite = app.buttons["收藏"]
        for _ in 0..<6 { if favorite.isHittable { break }; libraryScroll.swipeUp() }
        XCTAssertTrue(favorite.isHittable); favorite.tap()
        app.buttons["稍后阅读"].tap()
        XCTAssertTrue(app.buttons["取消收藏"].exists); XCTAssertTrue(app.buttons["移出稍后阅读"].exists)
        capture("R3-L04", app: app, feature: "library", state: "favorite-and-later-saved", origin: "explicit-original-fixture-URLProtocol")
        app.terminate(); app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = "round3-import-offline"; app.launch()
        openLibrary(app)
        let savedFavorite = app.buttons["取消收藏"]
        for _ in 0..<6 { if savedFavorite.isHittable { break }; libraryScroll.swipeUp() }
        XCTAssertTrue(savedFavorite.isHittable); XCTAssertTrue(app.buttons["移出稍后阅读"].exists)
        capture("R3-L05", app: app, feature: "library", state: "restart-retains-flags-network-unavailable", origin: "URLProtocol-offline-original-fixture")
        for _ in 0..<6 { if discover.isHittable { break }; libraryScroll.swipeDown() }
        XCTAssertTrue(app.buttons["library-discover"].isHittable)
        app.buttons["library-discover"].coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["无法导入完整文章，未添加到本地文章库。"].waitForExistence(timeout: 25))
        XCTAssertTrue(inventory.waitForExistence(timeout: 10))
        XCTAssertEqual(inventory.label, "共 1 篇")
        capture("R3-L06", app: app, feature: "library", state: "refresh-failed-existing-complete-local-version-preserved", origin: "URLProtocol-offline-original-fixture")
        let local = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'")).firstMatch
        for _ in 0..<6 { if local.isHittable { break }; libraryScroll.swipeUp() }
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
        let detail = app.buttons["dictionary-details"]; XCTAssertTrue(detail.waitForExistence(timeout: 10))
        for _ in 0..<15 { if detail.isEnabled { break }; _ = app.staticTexts["dictionary-providers"].waitForExistence(timeout: 1) }
        XCTAssertTrue(detail.isEnabled); detail.tap()
        let nested = app.links["networks"].firstMatch
        for _ in 0..<12 { if nested.exists && nested.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(nested.isHittable); nested.tap()
        let nestedHeadword = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "dictionary-headword", "network")).firstMatch
        XCTAssertTrue(nestedHeadword.waitForExistence(timeout: 10))
        capture("R3-D66", app: app, feature: "dictionary-context", state: "nested-word-from-provider-definition", origin: "explicit-original-provider-fixture-not-production-network")
        XCTAssertEqual(app.buttons.matching(identifier: "close-word").count, 1)
        app.buttons["close-word"].tap(); XCTAssertTrue(app.buttons["关闭详细释义"].waitForExistence(timeout: 10))
        app.buttons["关闭详细释义"].tap(); XCTAssertTrue(app.buttons["返回今日"].waitForExistence(timeout: 10)); app.buttons["返回今日"].tap()
        app.tabBars.buttons["词汇"].tap()
        let entry = app.buttons["vocabulary-entry-network"]
        for _ in 0..<6 { if entry.exists && entry.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(entry.isHittable); entry.tap()
        let contexts = app.buttons["遇见这个词的句子"]; for _ in 0..<12 { if contexts.exists && contexts.isHittable { break }; app.swipeUp() }; XCTAssertTrue(contexts.isHittable); contexts.tap()
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
            let detail = app.buttons["dictionary-details"]; XCTAssertTrue(detail.waitForExistence(timeout: 10))
            for _ in 0..<15 { if detail.isEnabled { break }; _ = app.staticTexts["dictionary-providers"].waitForExistence(timeout: 1) }
            XCTAssertTrue(detail.isEnabled); detail.tap()
            let synonyms = app.buttons["dictionary-synonym-comparison"]
            for _ in 0..<20 { if synonyms.exists && synonyms.isHittable { break }; swipeDictionary(app) }
            XCTAssertTrue(synonyms.isHittable); synonyms.tap()
            let link = app.buttons["dictionary-compare-network"]; XCTAssertTrue(link.waitForExistence(timeout: 10)); link.tap()
            XCTAssertTrue(app.navigationBars["同义词对照"].waitForExistence(timeout: 10))
            if mode == "loading" { XCTAssertTrue(app.descendants(matching: .any)["dictionary-comparison-loading"].waitForExistence(timeout: 5)) }
            else if mode == "empty" { XCTAssertTrue(app.staticTexts["dictionary-comparison-empty"].waitForExistence(timeout: 10)) }
            else { XCTAssertTrue(app.buttons["dictionary-comparison-retry"].waitForExistence(timeout: 10)) }
            capture("R3-D\(50 + index)", app: app, feature: "dictionary-comparison", state: mode, origin: "explicit-original-provider-fixture-not-production-network")
            if mode == "retry" {
                app.buttons["dictionary-comparison-retry"].tap()
                let definition = app.staticTexts["网络（原创比较测试义）"]
                XCTAssertTrue(definition.waitForExistence(timeout: 10)); XCTAssertFalse(app.buttons["dictionary-comparison-retry"].exists)
                capture("R3-D54", app: app, feature: "dictionary-comparison", state: "retry-success-with-original-provider-definition", origin: "explicit-original-provider-fixture-not-production-network")
            }
        }
    }
    func testDictionaryProviderFailureEmptyLoadingAndOfflineCacheEvidence() throws {
        // Retain all seven historical transport/cache scenarios under the sole
        // MDX contract: a failing engine cannot fall back to another provider.
        for (index, mode) in ["loading", "single-failed", "all-failed", "empty", "cache", "offline", "free-unavailable"].enumerated() {
            let app = launch("round3-dictionary-" + mode)
            XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
            let word = app.buttons["word-Internet"].firstMatch; XCTAssertTrue(word.waitForExistence(timeout: 10)); word.tap()
            XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10))
            if mode == "loading" { XCTAssertTrue(app.descendants(matching: .any)["dictionary-loading"].firstMatch.waitForExistence(timeout: 5)) }
            else if ["all-failed", "offline"].contains(mode) {
                XCTAssertTrue(app.staticTexts["dictionary-resource-error"].waitForExistence(timeout: 15))
                XCTAssertFalse(app.buttons["dictionary-details"].isEnabled); XCTAssertFalse(app.staticTexts["暂无英中释义"].exists)
                XCTAssertTrue(app.buttons["词典暂不可用，重试"].exists)
            } else if mode == "empty" { XCTAssertTrue(app.staticTexts["暂无英中释义"].waitForExistence(timeout: 15)) }
            else {
                let detail = app.buttons["dictionary-details"]
                expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: detail); waitForExpectations(timeout: 15); detail.tap()
                let providers = app.staticTexts["dictionary-providers"]
                for _ in 0..<15 { if providers.exists && providers.isHittable { break }; app.swipeUp() }
                XCTAssertTrue(providers.exists); XCTAssertTrue(providers.label.contains("内置 MDX"))
                XCTAssertFalse(providers.label.contains("Wiktionary")); XCTAssertFalse(providers.label.contains("Free Dictionary API"))
            }
            capture("R3-D" + String(format: "%02d", index + 1), app: app, feature: "dictionary", state: mode, origin: "explicit-original-provider-fixture-not-production-MDX")
            app.terminate()
        }
    }
    func testLiveMultipleSourcesLibraryFiltersAndCompleteLocalReaderEvidence() throws {
        let app = launch("round3-network-all"); openLibrary(app)
        app.buttons["library-discover"].tap()
        XCTAssertTrue(app.staticTexts["article-notice"].waitForExistence(timeout: 240), "Real publisher discovery must complete; no seeded articles")
        capture("R3-S00", app: app, feature: "article", state: "live-multiple-source-import-library", origin: "production-network-empty-isolated-store")
        let results = app.buttons["article-discovery-results"].firstMatch
        for _ in 0..<12 { if results.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(results.isHittable); results.tap()
        let imported = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "article-discovery-result-", "已导入"))
        XCTAssertTrue(imported.firstMatch.waitForExistence(timeout: 10))
        capture("R4-P02-actual-sources", app: app, feature: "article", state: "actual-per-source-complete-import-outcomes", origin: "production-network-empty-isolated-store")
        // Unlock through actual app actions, never by inserting completed cycles or review evidence.
        app.navigationBars.buttons.firstMatch.tap()
        let summary = app.buttons["article-library-body"]
        for _ in 0..<12 { if summary.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(summary.isHittable)
        let count = summary.label.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.first ?? 0
        XCTAssertGreaterThanOrEqual(count, 2)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'today-source-'")).count, 0)
        capture("R3-S01", app: app, feature: "today", state: "live-article-inventory-summary-without-duplicate-list", origin: "production-network-empty-isolated-store")
        let task = app.buttons["open-reader"]
        for _ in 0..<15 { if task.exists && task.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(task.waitForExistence(timeout: 10)); XCTAssertTrue(task.isHittable); task.tap()
        XCTAssertTrue(app.buttons["finish-reading"].waitForExistence(timeout: 10)); app.buttons["finish-reading"].tap()
        if app.alerts.buttons["确认我已读完"].waitForExistence(timeout: 2) { app.alerts.buttons["确认我已读完"].tap() }
        XCTAssertTrue(app.staticTexts["reading-completed"].waitForExistence(timeout: 10)); app.buttons["返回今日"].tap()
        app.tabBars.buttons["复习"].tap()
        XCTAssertTrue(app.staticTexts["今天没有到期词汇。"].waitForExistence(timeout: 10))
        app.tabBars.buttons["今日"].tap(); XCTAssertTrue(app.staticTexts["cycle-completed"].waitForExistence(timeout: 10)); openLibrary(app)
        let sources = [("wikipedia", "Wikipedia"), ("wikinews", "Wikinews"), ("bbc", "BBC News"), ("reuters", "Reuters"), ("ap", "AP News"), ("guardian", "The Guardian"), ("npr", "NPR"), ("dw", "Deutsche Welle"), ("voa", "VOA Learning English"), ("nasa", "NASA"), ("sciencedaily", "ScienceDaily"), ("phys", "Phys.org"), ("smithsonian", "Smithsonian Magazine")]
        let list = app.collectionViews["article-library-list"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        var inspected = 0
        for (id, title) in sources {
            let filter = app.buttons["library-source-filter"]
            for _ in 0..<12 { if filter.isHittable { break }; list.swipeDown() }
            XCTAssertTrue(filter.isHittable); filter.tap()
            let choice = app.buttons[title]
            guard choice.exists else {
                let all = app.buttons["全部来源"]; XCTAssertTrue(all.exists); XCTAssertTrue(all.isHittable); all.tap(); continue
            }
            choice.tap()
            let sourceLabel = list.staticTexts.matching(identifier: "library-row-source-\(id)").firstMatch
            let openButtons = list.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'"))
            var visibleArticle: XCUIElement?
            for _ in 0..<12 {
                if sourceLabel.exists, let readable = openButtons.allElementsBoundByIndex.first(where: { $0.isEnabled && $0.isHittable }) {
                    visibleArticle = readable
                    break
                }
                let upper = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
                let lower = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.69))
                if let button = openButtons.allElementsBoundByIndex.first(where: \.isEnabled),
                   button.frame.midY < app.navigationBars.firstMatch.frame.maxY {
                    upper.press(forDuration: 0.05, thenDragTo: lower)
                } else {
                    lower.press(forDuration: 0.05, thenDragTo: upper)
                }
            }
            let open = try XCTUnwrap(visibleArticle, "No visible readable article for imported source \(id)\n\(list.debugDescription)")
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
        let retry = app.buttons["add-word"]; XCTAssertEqual(retry.label, "重试保存生词"); retry.tap()
        let undo = app.buttons["undo-word"]
        for _ in 0..<5 { if undo.exists && undo.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(undo.waitForExistence(timeout: 10)); XCTAssertTrue(undo.isHittable); XCTAssertFalse(error.exists)
        capture("R3-V02", app: app, feature: "vocabulary", state: "safe-retry-save-success", origin: "explicit-one-shot-Repository-save-fault-bundled-RFC")
        app.buttons["close-word"].tap(); app.buttons["返回今日"].tap(); app.tabBars.buttons["词汇"].tap()
        XCTAssertTrue(app.buttons["vocabulary-entry-internet"].waitForExistence(timeout: 10))
        capture("R3-V03", app: app, feature: "vocabulary", state: "retry-result-in-persistent-notebook", origin: "explicit-one-shot-Repository-save-fault-bundled-RFC")
    }
    func testArticleLoadingCanCancelWithoutLeavingCandidateRecords() throws {
        let app = launch("round3-import-loading"); openLibrary(app); app.buttons["library-discover"].tap()
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
            XCTAssertTrue(app.staticTexts["dictionary-headword"].waitForExistence(timeout: 10)); XCTAssertEqual(app.staticTexts["dictionary-headword"].label, lemma)
            capture("R3-D" + String(index + 10), app: app, feature: "dictionary", state: "surface-" + surface, origin: "explicit-original-context-fixture-real-bundled-MDX")
            if !phrase.isEmpty {
                app.buttons["dictionary-details"].tap(); XCTAssertTrue(app.buttons["关闭详细释义"].waitForExistence(timeout: 10))
                let phraseButton = app.buttons["dictionary-context-phrase-" + phrase]
                for _ in 0..<30 { if phraseButton.exists && phraseButton.isHittable { break }; swipeDictionary(app) }
                XCTAssertTrue(phraseButton.isHittable); phraseButton.tap()
                let phraseHeadword = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "dictionary-headword", phrase)).firstMatch
                XCTAssertTrue(phraseHeadword.waitForExistence(timeout: 10))
                capture("R3-D" + String(index + 20), app: app, feature: "dictionary", state: "nested-phrase-" + phrase, origin: "explicit-original-context-fixture-real-bundled-MDX")
                app.buttons["close-word"].firstMatch.tap(); app.buttons["返回查词"].tap()
                XCTAssertTrue(app.staticTexts["dictionary-headword"].waitForExistence(timeout: 10)); XCTAssertEqual(app.staticTexts["dictionary-headword"].label, lemma)
                capture("R3-D" + String(index + 60), app: app, feature: "dictionary", state: "returned-from-nested-phrase-" + phrase, origin: "explicit-original-context-fixture-real-bundled-MDX")
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
            capture("R3-D" + String(index + 30), app: app, feature: "dictionary", state: "reader-popup-theme-" + theme, theme: theme, origin: "real-bundled-RFC-real-bundled-MDX")
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
        if word.value as? String != "已选择" { word.tap() }
        meaning.tap()
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
            let option = app.buttons["match-word-" + word]
            if option.value as? String != "已选择" { option.tap() }
            app.buttons["match-meaning-" + meaning].tap()
        }
        for word in ["internet", "document", "book"] {
            let field = app.textFields["cloze-answer"]; XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText(word)
            app.buttons["submit-spelling"].tap()
        }
        XCTAssertTrue(app.staticTexts["本次复习已保存"].waitForExistence(timeout: 10))
        app.buttons["查看本次复习记录"].tap()
        let hard = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Hard' AND label CONTAINS '原定' AND label CONTAINS '下次复习'")).firstMatch
        let good = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Good' AND label CONTAINS '原定' AND label CONTAINS '下次复习'")).firstMatch
        XCTAssertTrue(hard.waitForExistence(timeout: 10)); XCTAssertTrue(good.exists)
        capture("R3-G01", app: app, feature: "review", state: "hard-good-original-and-next-due", origin: "explicit-review-seed-real-RFC-and-personal-meanings")
        app.terminate(); app.launch(); app.tabBars.buttons["复习"].tap()
        XCTAssertTrue(app.buttons["查看本次复习记录"].waitForExistence(timeout: 10)); app.buttons["查看本次复习记录"].tap()
        XCTAssertTrue(hard.waitForExistence(timeout: 10)); XCTAssertTrue(good.exists)
        capture("R3-G02", app: app, feature: "review", state: "persisted-grade-and-schedule-after-restart", origin: "explicit-review-seed-real-RFC-and-personal-meanings")
    }
    func testNoteSaveFailurePreservesDraftAndNeverLeavesOldSuccessLabel() throws {
        let app = launch("round3-storage-note")
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 15)); app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["word-Internet"].firstMatch.waitForExistence(timeout: 10)); app.buttons["word-Internet"].firstMatch.tap()
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10)); app.buttons["close-word"].tap(); app.buttons["返回今日"].tap(); app.tabBars.buttons["词汇"].tap()
        let entry = app.buttons["vocabulary-entry-internet"]; XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        let notes = app.textFields["vocabulary-notes"]
        for _ in 0..<20 { if notes.exists && notes.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(notes.isHittable); notes.tap(); notes.typeText("First note")
        app.buttons["完成输入"].tap()
        expectation(for: NSPredicate(format: "label == %@", "已自动保存"), evaluatedWith: app.staticTexts["annotation-save-state"]); waitForExpectations(timeout: 10)
        capture("R3-V04", app: app, feature: "vocabulary", state: "initial-note-autosave-success", origin: "explicit-Repository-note-save-fault-real-MDX")
        notes.tap(); notes.typeText(" Second note draft"); app.buttons["完成输入"].tap()
        XCTAssertTrue(app.staticTexts["明确故障注入：释义与笔记保存失败，草稿已保留。"].waitForExistence(timeout: 10))
        XCTAssertNotEqual(app.staticTexts["annotation-save-state"].label, "已自动保存"); XCTAssertTrue((notes.value as? String)?.contains("Second note draft") == true)
        capture("R3-V05", app: app, feature: "vocabulary", state: "note-save-failed-draft-kept-no-stale-success", origin: "explicit-Repository-note-save-fault-real-MDX")
        app.buttons["重试保存"].tap()
        expectation(for: NSPredicate(format: "label == %@", "已自动保存"), evaluatedWith: app.staticTexts["annotation-save-state"]); waitForExpectations(timeout: 10)
        capture("R3-V06", app: app, feature: "vocabulary", state: "note-safe-retry-success", origin: "explicit-Repository-note-save-fault-real-MDX")
        app.terminate(); app.launch(); app.tabBars.buttons["词汇"].tap(); XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        for _ in 0..<20 { if notes.exists && notes.isHittable { break }; app.swipeUp() }
        XCTAssertTrue((notes.value as? String)?.contains("Second note draft") == true)
        capture("R3-V07", app: app, feature: "vocabulary", state: "note-retry-result-after-process-restart", origin: "explicit-Repository-note-save-fault-real-MDX")
    }
    private func swipeDictionary(_ app: XCUIApplication) {
        let scroll = app.scrollViews["dictionary-detail-scroll"].firstMatch
        let area = scroll.exists ? scroll : app
        let start = area.coordinate(withNormalizedOffset: CGVector(dx: 0.66, dy: 0.76))
        start.press(forDuration: 0.05, thenDragTo: area.coordinate(withNormalizedOffset: CGVector(dx: 0.66, dy: 0.19)))
    }
    /// Scrolling can retain offscreen accessibility elements. Exercise a word in the visible viewport.
    private func visibleWord(in app: XCUIApplication) -> XCUIElement {
        let words = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'word-'"))
        let token = words.allElementsBoundByIndex.first { $0.isHittable && app.windows.firstMatch.frame.intersects($0.frame) }
        XCTAssertNotNil(token, "The scrolled reader must expose a real, visible, tappable word")
        return token ?? words.firstMatch
    }
    /// Sample only the middle of the board's gap. Button text/icons cannot satisfy this assertion.
    private func connectionPixels(app: XCUIApplication) -> Int {
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
        let left = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'match-word-'")).allElementsBoundByIndex.map(\.frame)
        let right = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'match-meaning-'")).allElementsBoundByIndex.map(\.frame)
        guard let gapStart = left.filter({ !$0.isEmpty }).map(\.maxX).max(),
              let gapEnd = right.filter({ !$0.isEmpty }).map(\.minX).min(), gapEnd - gapStart > 12 else { return 0 }
        let middle = Int(Double((gapStart + gapEnd) / 2) * sx)
        let top = max(0, Int(Double(board.frame.minY) * sy)), bottom = min(height, Int(Double(board.frame.maxY) * sy))
        guard top < bottom, middle > 4, middle < width - 4 else { return 0 }
        var count = 0
        for y in top..<bottom { for x in (middle - 3)...(middle + 3) {
            let i = (y * width + x) * 4
            let red = Int(bytes[i]), green = Int(bytes[i + 1]), blue = Int(bytes[i + 2])
            if max(red, green, blue) - min(red, green, blue) > 55 { count += 1 }
        } }
        return count
    }
}
