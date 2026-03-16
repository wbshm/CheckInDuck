//
//  CheckInDuckUITestsLaunchTests.swift
//  CheckInDuckUITests
//

import XCTest

final class CheckInDuckUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
