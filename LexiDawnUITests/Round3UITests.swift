import XCTest
import UIKit
import ImageIO

final class Round3UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false; XCUIDevice.shared.orientation = .portrait }
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication(); app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = scenario
        app.launchEnvironment["LEXIDAWN_UI_STORE_ID"] = UUID().uuidString; app.launch(); return app
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
        app.buttons["保存个人释义与笔记"].tap()
        XCTAssertTrue(app.staticTexts["已保存"].waitForExistence(timeout: 10))
        capture("R3-C04", app: app, feature: "vocabulary", state: "explicit-personal-meaning-saved", origin: origin)
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
        let cases = [("offline", "R3-A10"), ("403", "R3-A11"), ("429", "R3-A12"), ("503", "R3-A13"), ("rights", "R3-A14"), ("parse", "R3-A15"), ("truncated", "R3-A16"), ("summary", "R3-A17"), ("404", "R3-A22")]
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
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-open-'")).firstMatch.tap()
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
        XCTAssertTrue(app.buttons["open-reader"].waitForExistence(timeout: 10)); app.buttons["open-reader"].tap()
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
            guard choice.exists else { app.tap(); continue }
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
        }
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
