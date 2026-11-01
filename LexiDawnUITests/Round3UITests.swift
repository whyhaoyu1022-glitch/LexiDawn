import XCTest
import UIKit

final class Round3UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false; XCUIDevice.shared.orientation = .portrait }
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication(); app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = scenario
        app.launchEnvironment["LEXIDAWN_UI_STORE_ID"] = UUID().uuidString; app.launch(); return app
    }
    private func capture(_ id: String, app: XCUIApplication, feature: String, state: String, theme: String = "system", origin: String = "fixture-real-rfc-isolated-learning-state") {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = id; image.lifetime = .keepAlways; add(image)
        let metadata: [String: String] = ["screenshotID": id, "featureID": feature, "screenName": feature, "state": state,
            "device": ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? UIDevice.current.name, "orientation": XCUIDevice.shared.orientation.isLandscape ? "landscape" : "portrait", "theme": theme,
            "testName": name, "fixtureOrProduction": origin, "fileName": id + ".png", "notes": "Native Simulator screenshot; no image generation."]
        if let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]) {
            let json = XCTAttachment(data: data, uniformTypeIdentifier: "public.json"); json.name = id + "-metadata"; json.lifetime = .keepAlways; add(json)
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
            if index == 0 { capture("R3-R02", app: app, feature: "reader", state: "landscape-body-visible") }
        }
        let body = app.otherElements["reader-body"].firstMatch
        XCTAssertTrue(body.exists); body.swipeUp()
        capture("R3-R03", app: app, feature: "reader", state: "scrolled-after-ten-rotations")
        let token = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'word-'")).firstMatch
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
        let token = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'word-'")).firstMatch
        XCTAssertTrue(token.waitForExistence(timeout: 10)); XCTAssertTrue(token.isHittable); token.tap()
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
        app.tabBars.buttons["今日"].tap(); app.buttons["open-reader"].tap()
        XCTAssertTrue(app.buttons["finish-reading"].waitForExistence(timeout: 10)); app.buttons["finish-reading"].tap()
        if app.alerts.buttons["确认我已读完"].waitForExistence(timeout: 2) { app.alerts.buttons["确认我已读完"].tap() }
        XCTAssertTrue(app.staticTexts["reading-completed"].waitForExistence(timeout: 10)); app.buttons["返回今日"].tap()
        app.tabBars.buttons["复习"].tap()
        let question = app.buttons["match-word-" + lemma]; XCTAssertTrue(question.waitForExistence(timeout: 90)); question.tap()
        let meaning = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'match-meaning-'")).firstMatch
        XCTAssertTrue(meaning.waitForExistence(timeout: 10)); meaning.tap()
        let spelling = app.textFields["cloze-answer"]; XCTAssertTrue(spelling.waitForExistence(timeout: 10))
        capture("R3-C05", app: app, feature: "review", state: "live-import-derived-spelling", origin: origin)
        spelling.tap(); spelling.typeText(lemma); app.buttons["submit-spelling"].tap()
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
        let cases = [("offline", "R3-A10"), ("403", "R3-A11"), ("429", "R3-A12"), ("503", "R3-A13"), ("rights", "R3-A14"), ("parse", "R3-A15"), ("truncated", "R3-A16"), ("summary", "R3-A17")]
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
        let search = app.searchFields.firstMatch; search.tap(); search.typeText("Explicit fixture")
        capture("R3-L02", app: app, feature: "library", state: "title-search-hit", origin: "explicit-original-fixture-URLProtocol")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Explicit fixture".count)); search.typeText("zzzzunfindable")
        XCTAssertTrue(app.staticTexts["没有匹配的完整文章"].waitForExistence(timeout: 10))
        capture("R3-L03", app: app, feature: "library", state: "title-search-no-result", origin: "explicit-original-fixture-URLProtocol")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "zzzzunfindable".count))
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() } else if app.buttons["取消"].exists { app.buttons["取消"].tap() }
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
    /// Sample only the middle of the board's gap. Button text/icons cannot satisfy this assertion.
    private func greenLinePixels(app: XCUIApplication) -> Int {
        let board = app.otherElements["matching-board"].firstMatch
        guard board.waitForExistence(timeout: 5), let image = app.screenshot().image.cgImage else { return 0 }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        let screen = app.windows.firstMatch.frame
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
