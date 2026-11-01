import XCTest
import UIKit

final class Round3UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false; XCUIDevice.shared.orientation = .portrait }
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication(); app.launchEnvironment["LEXIDAWN_UI_SCENARIO"] = scenario
        app.launchEnvironment["LEXIDAWN_UI_STORE_ID"] = UUID().uuidString; app.launch(); return app
    }
    private func capture(_ id: String, app: XCUIApplication, feature: String, state: String, theme: String = "system") {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = id; image.lifetime = .keepAlways; add(image)
        let metadata: [String: String] = ["screenshotID": id, "featureID": feature, "screenName": feature, "state": state,
            "device": UIDevice.current.model, "orientation": XCUIDevice.shared.orientation.isLandscape ? "landscape" : "portrait", "theme": theme,
            "testName": name, "fixtureOrProduction": "fixture-real-rfc-isolated-learning-state", "fileName": id + ".png", "notes": "Native Simulator screenshot; no image generation."]
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
