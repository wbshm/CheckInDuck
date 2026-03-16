//
//  CheckInDuckUITests.swift
//  CheckInDuckUITests
//

import XCTest

final class CheckInDuckUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
    }
}
