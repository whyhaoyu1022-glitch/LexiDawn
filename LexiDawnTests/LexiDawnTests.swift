import XCTest
@testable import LexiDawn

final class LexiDawnTests: XCTestCase {
    func testDesignTokensUseFourPointGrid() {
        XCTAssertEqual(LexiDawnSpacing.xs, 4)
        XCTAssertEqual(LexiDawnSpacing.sm, 8)
        XCTAssertEqual(LexiDawnSpacing.md, 16)
        XCTAssertEqual(LexiDawnSpacing.lg, 24)
        XCTAssertEqual(LexiDawnSpacing.xl, 32)
        XCTAssertEqual(LexiDawnSpacing.xxl, 40)
    }

    func testRootTabViewCanBeConstructed() {
        _ = RootTabView()
    }
}
