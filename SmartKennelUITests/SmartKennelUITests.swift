//
//  SmartKennelUITests.swift
//  SmartKennelUITests
//
//  Smoke-level UI test. The auto-generated stubs (empty testExample +
//  testLaunchPerformance) were removed — the performance metric is slow and
//  flaky in sandboxed CI and the empty test asserted nothing. This single
//  launch test verifies the app starts and reaches the foreground without
//  crashing, which is the meaningful smoke check for a UI test target.

import XCTest

final class SmartKennelUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesToForeground() throws {
        let app = XCUIApplication()
        app.launch()
        // Reaching .runningForeground means the app launched without crashing
        // during init / first view construction.
        XCTAssertEqual(app.state, .runningForeground,
                       "App did not reach the foreground after launch")
    }
}
