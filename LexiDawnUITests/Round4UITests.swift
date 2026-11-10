import XCTest
import UIKit
import ImageIO

final class Round4UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false; XCUIDevice.shared.orientation = .portrait }
    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let hierarchy = XCTAttachment(string: XCUIApplication().debugDescription); hierarchy.name = "Round4-failure-hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
            capture("R4-diagnostic-" + name.components(separatedBy: " ").last!.replacingOccurrences(of: "]", with: ""), app: XCUIApplication(), feature: "diagnostic", state: "failed-test-actual-screen-not-feature-acceptance") }
        XCUIDevice.shared.orientation = .portrait
    }
    private func launch(_ scenario: String, fontSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication(); app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = scenario
        if let fontSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", fontSize] }
        app.launchEnvironment["LEXIDAWN_UI_STORE_ID"] = UUID().uuidString; app.launch(); return app
    }
    private func reach(_ element: XCUIElement, app: XCUIApplication, upward: Bool = true, count: Int = 12) {
        if app.keyboards.firstMatch.exists, app.buttons["完成输入"].exists { app.buttons["完成输入"].tap() }
        for _ in 0..<count {
            if element.exists && element.isHittable { break }
            let bounds = app.windows.firstMatch.frame
            let above = element.exists && !element.frame.isEmpty && element.frame.maxY < bounds.minY + 100
            let below = element.exists && !element.frame.isEmpty && element.frame.minY > bounds.maxY - 120
            let scrollUp = above ? false : below ? true : upward
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: scrollUp ? 0.6 : 0.35))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: scrollUp ? 0.35 : 0.6)))
        }
        XCTAssertTrue(element.exists); XCTAssertTrue(element.isHittable)
    }
    private func reader(_ app: XCUIApplication) {
        let open = app.buttons["open-reader"]; XCTAssertTrue(open.waitForExistence(timeout: 15)); open.tap()
        XCTAssertTrue(app.otherElements["reader-body"].firstMatch.waitForExistence(timeout: 10))
    }
    private func tapWord(_ word: String, app: XCUIApplication) {
        let button = app.buttons["word-" + word].firstMatch
        for _ in 0..<10 { if button.exists && button.isHittable { break }; app.otherElements["reader-body"].firstMatch.swipeUp() }
        XCTAssertTrue(button.isHittable); button.tap()
        XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10))
    }
    private func replace(_ field: XCUIElement, with value: String) {
        XCTAssertTrue(field.isHittable); field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: min(200, (field.value as? String)?.count ?? 0))); field.typeText(value)
    }
    private func capture(_ id: String, app: XCUIApplication, feature: String, state: String, theme: String = "system", provenance: String = "explicit-original-Round4-UI-fixture-real-Repository-not-live-provider") {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? UIDevice.current.name
        let safe = device.map { $0.isLetter || $0.isNumber || $0 == "-" ? String($0) : "-" }.joined()
        let orientation = XCUIDevice.shared.orientation.isLandscape ? "landscape" : "portrait"
        let categoryIndex = app.launchArguments.firstIndex(of: "-UIPreferredContentSizeCategoryName")
        let category = categoryIndex.flatMap { app.launchArguments.indices.contains($0 + 1) ? app.launchArguments[$0 + 1] : nil } ?? UITraitCollection.current.preferredContentSizeCategory.rawValue
        let identifier = id + "-" + theme + "-" + orientation + "-" + safe
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = identifier; image.lifetime = .keepAlways; add(image)
        let row: [String: String] = ["screenshotID": identifier, "featureID": feature, "screenName": feature, "state": state, "device": device,
            "orientation": orientation, "theme": theme, "osVersion": UIDevice.current.systemVersion, "testName": name,
            "fontSize": category,
            "fixtureOrProduction": provenance, "fileName": identifier + ".png", "notes": "Actual native Simulator capture. Reference images and generated images are not screenshots."]
        let data = try! JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
        let metadata = XCTAttachment(data: data, uniformTypeIdentifier: "public.json"); metadata.name = identifier + "-metadata"; metadata.lifetime = .keepAlways; add(metadata)
    }
    func testBilingualReferenceHierarchyCompactPopupAndReliableEditLock() throws {
        let app = launch("round4-rich"); reader(app); tapWord("nod", app: app)
        let close = app.buttons["close-word"]
        let card = app.descendants(matching: .any)["compact-word-card"].firstMatch
        XCTAssertGreaterThan(card.frame.height, 100); XCTAssertLessThan(card.frame.height, 300)
        XCTAssertLessThan(card.frame.width, app.windows.firstMatch.frame.width)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "点头")).firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Explicit English-only fixture'")).count, 0)
        capture("R4-P21-compact", app: app, feature: "reader-dictionary", state: "small-bilingual-anchored-lookup")
        app.buttons["dictionary-details"].tap()
        XCTAssertTrue(app.buttons["关闭详细释义"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["n. 名词"].exists)
        capture("R4-F22-reference-top", app: app, feature: "dictionary-detail", state: "headword-IPA-noun-senses-bilingual-examples")
        let verb = app.staticTexts["v. 动词"]; reach(verb, app: app)
        capture("R4-F22-reference-middle", app: app, feature: "dictionary-detail", state: "verb-group-forms-and-examples")
        let phrases = app.staticTexts["短语与搭配"]; reach(phrases, app: app)
        capture("R4-F22-reference-end", app: app, feature: "dictionary-detail", state: "phrase-section-and-unobscured-bottom-controls")
        app.buttons["关闭详细释义"].tap(); XCTAssertTrue(app.buttons["close-word"].waitForExistence(timeout: 10)); app.buttons["close-word"].tap()
        app.buttons["返回今日"].tap(); app.tabBars.buttons["词汇"].tap()
        let entry = app.buttons["vocabulary-entry-nod"]; reach(entry, app: app); entry.tap()
        let locked = app.descendants(matching: .any)["personal-meaning-disabled"].firstMatch; reach(locked, app: app)
        XCTAssertFalse(app.textFields["personal-meaning"].exists)
        capture("R4-F23-reliable-lock", app: app, feature: "vocabulary-detail", state: "reliable-Chinese-locks-personal-senses-not-notes")
    }
    func testReaderCompleteTitleTenRotationsAndThreeCompactThemes() throws {
        let app = launch("round4-reader"); reader(app)
        let title = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'A complete original English title'")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10)); XCTAssertGreaterThan(title.frame.height, 30)
        capture("R4-P06-title", app: app, feature: "reader", state: "full-wrapping-scrollable-title")
        for index in 0..<10 {
            XCUIDevice.shared.orientation = index.isMultiple(of: 2) ? .landscapeLeft : .portrait
            let body = app.otherElements["reader-body"].firstMatch
            XCTAssertTrue(body.waitForExistence(timeout: 10)); XCTAssertGreaterThan(body.frame.height, 80)
            body.swipeUp()
            let words = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'word-'"))
            XCTAssertTrue(words.allElementsBoundByIndex.contains(where: \.isHittable))
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        capture("R4-P06-landscape", app: app, feature: "reader", state: "real-body-visible-after-ten-rotations")
        XCUIDevice.shared.orientation = .portrait
        for (theme, label) in [("light", "浅色"), ("dark", "深色"), ("paper", "暖纸色")] {
            app.buttons["reader-appearance"].tap(); app.buttons[label].tap()
            let dismissed = NSPredicate(format: "exists == false")
            expectation(for: dismissed, evaluatedWith: app.buttons["关闭外观设置"])
            waitForExpectations(timeout: 10)
            XCTAssertTrue(app.buttons["reader-appearance"].isHittable)
            capture("R4-P06-theme-" + theme, app: app, feature: "reader", state: "whole-native-reader-theme", theme: theme)
        }
    }
    func testEnglishOnlyAllowsStructuredPersonalAutosaveAndNotesRestore() throws {
        let app = launch("round4-english-only"); reader(app); tapWord("nod", app: app)
        XCTAssertTrue(app.staticTexts["暂无英中释义"].waitForExistence(timeout: 15))
        capture("R4-F23-English-only", app: app, feature: "dictionary", state: "English-only-is-no-usable-Chinese-definition")
        app.buttons["close-word"].tap(); app.buttons["返回今日"].tap(); app.tabBars.buttons["词汇"].tap()
        app.buttons["vocabulary-entry-nod"].tap()
        let add = app.buttons["添加义项"]; reach(add, app: app); add.tap()
        let part = app.buttons["personal-part-of-speech"].firstMatch; reach(part, app: app); part.tap(); app.buttons["n. 名词"].tap()
        let meaning = app.textFields["personal-meaning"].firstMatch; reach(meaning, app: app); replace(meaning, with: "明确的个人中文测试义")
        if app.buttons["完成输入"].exists { app.buttons["完成输入"].tap() }
        let confirm = app.switches["确认作为学习义项"].firstMatch; reach(confirm, app: app); confirm.tap()
        let notes = app.textFields["vocabulary-notes"]; reach(notes, app: app); replace(notes, with: "Round Four autosaved note")
        capture("R4-P09-keyboard", app: app, feature: "vocabulary", state: "personal-POS-Chinese-and-note-editing")
        app.navigationBars.buttons["生词本"].tap()
        XCTAssertTrue(app.buttons["vocabulary-entry-nod"].waitForExistence(timeout: 10))
        app.terminate(); app.launch(); app.tabBars.buttons["词汇"].tap(); app.buttons["vocabulary-entry-nod"].tap()
        reach(app.textFields["vocabulary-notes"], app: app)
        XCTAssertEqual(app.textFields["vocabulary-notes"].value as? String, "Round Four autosaved note")
        XCTAssertFalse(app.buttons["save-vocabulary-annotation"].exists)
        capture("R4-P09-restored", app: app, feature: "vocabulary", state: "autosave-restored-after-real-process-restart")
    }
    func testMatchingLinesWrongFeedbackRevealCorrectionAndCompletion() throws {
        let app = launch("round4-review"); app.buttons["open-review"].tap()
        let nod = app.buttons["match-word-nod"]; XCTAssertTrue(nod.waitForExistence(timeout: 20))
        capture("R4-P10-initial", app: app, feature: "matching", state: "two-columns-before-any-answer")
        nod.tap(); capture("R4-P10-selected", app: app, feature: "matching", state: "English-selected")
        app.buttons["match-meaning-书"].tap()
        XCTAssertTrue(app.staticTexts["review-feedback"].waitForExistence(timeout: 5))
        XCTAssertTrue(nod.isEnabled)
        capture("R4-P10-wrong", app: app, feature: "matching", state: "incorrect-pair-remains-retryable")
        app.buttons["match-meaning-点头"].tap()
        XCTAssertFalse(nod.isEnabled); XCTAssertFalse(app.buttons["match-meaning-点头"].isEnabled)
        XCTAssertGreaterThan(greenLinePixels(app), 0)
        capture("R4-P10-one-line", app: app, feature: "matching", state: "visible-connection-both-ends-disabled")
        app.buttons["match-word-book"].tap(); app.buttons["match-meaning-书"].tap()
        capture("R4-P10-multiple-lines", app: app, feature: "matching", state: "multiple-real-retained-lines")
        app.buttons["返回今日"].tap(); app.terminate(); app.launch(); app.buttons["open-review"].tap()
        XCTAssertTrue(app.buttons["match-word-nod"].waitForExistence(timeout: 15)); XCTAssertFalse(app.buttons["match-word-nod"].isEnabled)
        capture("R4-P10-restored", app: app, feature: "matching", state: "persisted-completed-pairs-after-restart")
        app.buttons["match-word-provide"].tap(); app.buttons["match-meaning-提供"].tap()
        let field = app.textFields["cloze-answer"]; XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["review-feedback"].exists)
        field.tap(); field.typeText("wrong")
        capture("R4-P18-keyboard", app: app, feature: "spelling", state: "new-question-no-prior-green-feedback")
        app.buttons["submit-spelling"].tap()
        capture("R4-P18-incorrect", app: app, feature: "spelling", state: "current-question-error-only")
        for index in 0..<3 {
            let reveal = app.buttons["显示答案"]; reach(reveal, app: app); reveal.tap()
            let answer = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '答案：'")).firstMatch
            XCTAssertTrue(answer.waitForExistence(timeout: 5)); let value = answer.label.replacingOccurrences(of: "答案：", with: "")
            XCTAssertTrue(app.textFields["cloze-answer"].exists)
            capture("R4-P19-revealed-\(index)", app: app, feature: "spelling", state: "answer-visible-awaiting-user-correction-Again")
            let current = app.textFields["cloze-answer"]; reach(current, app: app, upward: false); replace(current, with: value)
            app.buttons["submit-spelling"].tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["review-completed"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["review-next-due"].exists)
        capture("R4-P12-complete", app: app, feature: "review", state: "concise-completion-without-schedule-wall")
        let logs = app.buttons["查看本次复习记录"]; reach(logs, app: app); logs.tap()
        XCTAssertTrue(app.staticTexts["review-next-due"].firstMatch.waitForExistence(timeout: 5))
        capture("R4-P12-records", app: app, feature: "review", state: "optional-persisted-Again-schedule-details")
    }
    func testPreflightCancelAndExplicitAllDeferralDoNotPretendAnswers() throws {
        let app = launch("round4-missing"); XCTAssertTrue(app.buttons["open-review"].waitForExistence(timeout: 15)); app.buttons["open-review"].tap()
        let alert = app.alerts["复习还未准备好"]; XCTAssertTrue(alert.waitForExistence(timeout: 20))
        XCTAssertFalse(app.textFields["cloze-answer"].exists)
        capture("R4-P08-preflight", app: app, feature: "review-entry", state: "missing-meaning-before-practice")
        alert.buttons["取消"].tap(); XCTAssertTrue(app.buttons["open-reader"].exists)
        app.buttons["open-review"].tap(); XCTAssertTrue(alert.waitForExistence(timeout: 20)); alert.buttons["本次延期该词"].tap()
        let confirm = app.buttons["确认本组全部延期"]; XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        capture("R4-P08-confirm-deferral", app: app, feature: "review-entry", state: "explicit-whole-selection-deferral-confirmation")
        confirm.tap()
        let state = app.staticTexts["本组已按你的选择延期，未计作答对。"]
        XCTAssertTrue(state.waitForExistence(timeout: 20)); XCTAssertFalse(app.textFields["cloze-answer"].exists)
        capture("R4-P08-deferred", app: app, feature: "review-entry", state: "user-deferral-distinct-from-no-due-words")
    }
    func testSettingsAutosaveAboutAndLibraryScopesRemainGated() throws {
        let app = launch("round4-library"); app.tabBars.buttons["我的"].tap()
        let name = app.textFields["settings-name"]; XCTAssertTrue(name.waitForExistence(timeout: 10)); replace(name, with: "Round Four")
        XCTAssertFalse(app.buttons["save-settings"].exists)
        if app.buttons["完成输入"].exists { app.buttons["完成输入"].tap() }
        app.tabBars.buttons["今日"].tap(); app.tabBars.buttons["我的"].tap()
        XCTAssertEqual(app.textFields["settings-name"].value as? String, "Round Four")
        capture("R4-P20-autosave", app: app, feature: "settings", state: "preferences-saved-without-save-button")
        let about = app.buttons["about-lexidawn"]; reach(about, app: app); about.tap()
        let developer = app.descendants(matching: .any)["about-developer"].firstMatch
        XCTAssertTrue(developer.waitForExistence(timeout: 10))
        XCTAssertTrue(developer.label.contains("Why Haoyu") || (developer.value as? String)?.contains("Why Haoyu") == true || developer.staticTexts["Why Haoyu"].exists)
        capture("R4-P20-about", app: app, feature: "about", state: "developer-and-real-bundle-version")
        app.tabBars.buttons["今日"].tap(); app.buttons["article-library"].tap()
        XCTAssertTrue(app.staticTexts["共 3 篇"].waitForExistence(timeout: 10))
        capture("R4-P04-counts", app: app, feature: "library", state: "total-count-and-visible-favorite-later-history-scopes")
        let favorite = app.buttons["收藏"].firstMatch; reach(favorite, app: app); favorite.tap()
        XCTAssertFalse(app.otherElements["reader-body"].exists)
        let scopes = app.segmentedControls["library-mode-filter"]
        reach(scopes, app: app, upward: false)
        scopes.buttons.matching(NSPredicate(format: "label BEGINSWITH '收藏'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["取消收藏"].firstMatch.waitForExistence(timeout: 5))
        capture("R4-P04-favorites", app: app, feature: "library", state: "favorite-filter-persistent-with-current-task-gate")
        scopes.buttons.matching(NSPredicate(format: "label BEGINSWITH '稍后'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["没有匹配的完整文章"].waitForExistence(timeout: 5))
        capture("R4-P04-later-empty", app: app, feature: "library", state: "empty-read-later-scope")
    }
    func testDiscoveryShowsRealSourceProgressAndCancelKeepsLocalStore() throws {
        let app = launch("round3-import-loading"); app.buttons["article-library"].tap(); app.buttons["发现完整文章"].tap()
        let source = app.staticTexts["article-discovery-active-sources"]
        XCTAssertTrue(source.waitForExistence(timeout: 10)); XCTAssertTrue(source.label.contains("Wikipedia"))
        capture("R4-P05-progress", app: app, feature: "article-discovery", state: "real-service-source-count-and-active-host-fixture-transport")
        app.buttons["cancel-article-discovery"].tap()
        XCTAssertTrue(app.staticTexts["已停止发现；已完整入库的文章保留。"].waitForExistence(timeout: 10))
        capture("R4-P05-cancelled", app: app, feature: "article-discovery", state: "cancelled-candidate-not-imported")
    }
    func testActualBundledMDXDetailAndSystemPronunciation() throws {
        let app = launch("round4-mdx-production"); reader(app); tapWord("nod", app: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "点头")).firstMatch.waitForExistence(timeout: 20))
        capture("R4-P21-real-MDX", app: app, feature: "reader-dictionary", state: "actual-bundled-MDX-compact", provenance: "real-bundled-MDX-with-explicit-original-article")
        app.buttons["dictionary-details"].tap()
        XCTAssertTrue(app.buttons["关闭详细释义"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["n. 名词"].exists)
        capture("R4-F22-real-top", app: app, feature: "dictionary-detail", state: "actual-MDX-noun-IPA-examples-reference-hierarchy", provenance: "real-bundled-MDX-with-explicit-original-article")
        let speak = app.buttons["dictionary-system-pronunciation"]; XCTAssertTrue(speak.exists); speak.tap()
        capture("R4-F22-system-pronunciation", app: app, feature: "dictionary-detail", state: "actual-system-pronunciation-start-or-unavailable", provenance: "real-bundled-MDX-and-iOS-system-TTS")
        if speak.label == "停止系统朗读" { speak.tap() }
        let verb = app.staticTexts["v. 动词"]; reach(verb, app: app)
        capture("R4-F22-real-middle", app: app, feature: "dictionary-detail", state: "actual-MDX-verb-section-reference-hierarchy", provenance: "real-bundled-MDX-with-explicit-original-article")
        let phrases = app.staticTexts["短语动词"]; reach(phrases, app: app)
        capture("R4-F22-real-phrases", app: app, feature: "dictionary-detail", state: "actual-MDX-phrasal-verbs", provenance: "real-bundled-MDX-with-explicit-original-article")
        let nested = app.buttons["dictionary-related-entry-nod off"].firstMatch; reach(nested, app: app); nested.tap()
        XCTAssertTrue(app.staticTexts["dictionary-full-headword"].waitForExistence(timeout: 10)); XCTAssertEqual(app.staticTexts["dictionary-full-headword"].label, "nod off")
        capture("R4-F22-real-internal-link", app: app, feature: "dictionary-detail", state: "actual-MDX-subentry-native-navigation", provenance: "real-bundled-MDX-internal-record")
        app.buttons["关闭详细释义"].tap()
        XCTAssertTrue(app.buttons["dictionary-related-entry-nod off"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["关闭详细释义"].tap(); app.buttons["close-word"].tap()
        XCTAssertTrue(app.otherElements["reader-body"].firstMatch.exists)
    }
    func testActualMDXReferenceLayoutThreeThemesLandscapeAndAccessibilityFont() throws {
        let app = launch("round4-mdx-production"); reader(app)
        for (theme, label) in [("light", "浅色"), ("dark", "深色"), ("paper", "暖纸色")] {
            app.buttons["reader-appearance"].tap(); app.buttons[label].tap(); tapWord("nod", app: app)
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["dictionary-details"]); waitForExpectations(timeout: 20)
            app.buttons["dictionary-details"].tap(); XCTAssertTrue(app.staticTexts["dictionary-ipa-summary"].waitForExistence(timeout: 10))
            capture("R4-F22-reference-top-" + theme, app: app, feature: "dictionary-detail", state: "actual-MDX-reference-headword-POS-numbered-senses", theme: theme, provenance: "real-bundled-MDX")
            reach(app.staticTexts["v. 动词"], app: app, count: 20)
            capture("R4-F22-reference-middle-" + theme, app: app, feature: "dictionary-detail", state: "actual-MDX-reference-verb-forms-paired-examples", theme: theme, provenance: "real-bundled-MDX")
            reach(app.staticTexts["来源：内置 MDX"], app: app, count: 25)
            capture("R4-F22-reference-end-" + theme, app: app, feature: "dictionary-detail", state: "actual-MDX-idioms-final-sense-bottom-controls-unobscured", theme: theme, provenance: "real-bundled-MDX")
            app.buttons["关闭详细释义"].tap(); app.buttons["close-word"].tap()
        }
        app.terminate()
        let large = launch("round4-mdx-production", fontSize: "UICTContentSizeCategoryAccessibilityXXXL"); reader(large); tapWord("nod", app: large)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: large.buttons["dictionary-details"]); waitForExpectations(timeout: 20)
        large.buttons["dictionary-details"].tap(); XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(large.buttons["关闭详细释义"].waitForExistence(timeout: 10)); reach(large.staticTexts["n. 名词"], app: large, count: 20)
        capture("R4-F22-accessibility-landscape", app: large, feature: "dictionary-detail", state: "actual-MDX-AXXXL-landscape-readable-content-and-close-control", provenance: "real-bundled-MDX-explicit-Dynamic-Type-setting")
    }
    func testActualMissingAndCorruptMDXResourcesShowErrorsAndDisableDetails() throws {
        for scenario in ["round4-mdx-missing", "round4-mdx-corrupt"] {
            let app = launch(scenario); reader(app); tapWord("nod", app: app)
            XCTAssertTrue(app.staticTexts["dictionary-resource-error"].waitForExistence(timeout: 15))
            XCTAssertFalse(app.buttons["dictionary-details"].isEnabled)
            XCTAssertFalse(app.staticTexts["暂无英中释义"].exists)
            capture("R4-F23-" + scenario, app: app, feature: "dictionary-error", state: "actual-native-resource-error-not-notFound", provenance: "real-native-MDX-provider-explicit-file-fault")
            app.terminate()
        }
    }
    func testActualOfflineSearchCreatesStructuredPersonalEntryAndRestoresAfterRestart() throws {
        let app = launch("round4-mdx-production")
        app.tabBars.buttons["词汇"].tap(); app.buttons["open-offline-dictionary"].tap()
        let query = app.textFields["dictionary-search-field"]
        XCTAssertTrue(query.waitForExistence(timeout: 10)); query.tap(); query.typeText("user\n")
        XCTAssertTrue(app.buttons["dictionary-search-result"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["dictionary-create-personal"].exists)
        capture("R4-F23-real-search", app: app, feature: "dictionary-search", state: "actual-offline-MDX-Chinese-result-personal-edit-locked", provenance: "real-bundled-MDX-no-dictionary-network")
        replace(query, with: "lexidawnuitestpersonal\n")
        let create = app.buttons["dictionary-create-personal"]
        XCTAssertTrue(create.waitForExistence(timeout: 20))
        capture("R4-F23-real-notFound", app: app, feature: "dictionary-search", state: "actual-MDX-notFound-not-resource-error", provenance: "real-bundled-MDX-no-dictionary-network")
        create.tap()
        let add = app.buttons["添加义项"]; reach(add, app: app); add.tap()
        let part = app.buttons["personal-part-of-speech"].firstMatch; reach(part, app: app); part.tap(); app.buttons["n. 名词"].tap()
        let meaning = app.textFields["personal-meaning"].firstMatch; reach(meaning, app: app); replace(meaning, with: "个人离线测试词义")
        if app.buttons["完成输入"].exists { app.buttons["完成输入"].tap() }
        let confirm = app.switches["确认作为学习义项"].firstMatch; reach(confirm, app: app); confirm.tap()
        let notes = app.textFields["vocabulary-notes"]; reach(notes, app: app); replace(notes, with: "Actual MDX absence, personal content")
        if app.buttons["完成输入"].exists { app.buttons["完成输入"].tap() }
        expectation(for: NSPredicate(format: "label == %@", "已自动保存"), evaluatedWith: app.staticTexts["annotation-save-state"]); waitForExpectations(timeout: 10)
        capture("R4-F23-real-personal-saved", app: app, feature: "personal-dictionary", state: "actual-MDX-notFound-structured-personal-POS-confirmed-notes-persisted", provenance: "real-bundled-MDX-and-user-created-content-real-Repository")
        app.terminate(); app.launch(); app.tabBars.buttons["词汇"].tap()
        let entry = app.buttons["vocabulary-entry-lexidawnuitestpersonal"]; reach(entry, app: app); entry.tap()
        reach(app.textFields["vocabulary-notes"], app: app)
        XCTAssertEqual(app.textFields["vocabulary-notes"].value as? String, "Actual MDX absence, personal content")
        capture("R4-F23-real-personal-restart", app: app, feature: "personal-dictionary", state: "actual-disk-personal-content-restored-after-process-restart", provenance: "real-bundled-MDX-and-user-created-content-real-Repository")
    }
    func testDictionaryPartialEmptyAndFailedStatesRemainCompact() throws {
        for mode in ["partial", "empty", "all-failed", "loading"] {
            let app = launch("round4-" + mode); reader(app); tapWord("nod", app: app)
            if mode == "partial" { XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "点头")).firstMatch.waitForExistence(timeout: 15)) }
            if mode == "empty" { XCTAssertTrue(app.staticTexts["暂无英中释义"].waitForExistence(timeout: 15)) }
            if mode == "all-failed" { XCTAssertTrue(app.buttons["词典暂不可用，重试"].waitForExistence(timeout: 15)) }
            if mode == "loading" { XCTAssertTrue(app.descendants(matching: .any)["dictionary-loading"].firstMatch.waitForExistence(timeout: 5)) }
            capture("R4-F22-" + mode, app: app, feature: "dictionary", state: mode)
            app.terminate()
        }
    }
    private func greenLinePixels(_ app: XCUIApplication) -> Int {
        let board = app.otherElements["matching-board"].firstMatch
        guard board.exists, let source = CGImageSourceCreateWithData(XCUIScreen.main.screenshot().pngRepresentation as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return 0 }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        let screen = app.windows.firstMatch.frame, sx = Double(width) / Double(screen.width), sy = Double(height) / Double(screen.height)
        let mid = Int(Double(board.frame.midX) * sx), first = max(0, Int(Double(board.frame.minY) * sy)), last = min(height, Int(Double(board.frame.maxY) * sy))
        guard first < last, mid > 4, mid < width - 4 else { return 0 }
        var count = 0
        for y in first..<last { for x in (mid-3)...(mid+3) { let i = (y*width+x)*4; if max(Int(bytes[i]), Int(bytes[i+1]), Int(bytes[i+2])) - min(Int(bytes[i]), Int(bytes[i+1]), Int(bytes[i+2])) > 40 { count += 1 } } }
        return count
    }
}
