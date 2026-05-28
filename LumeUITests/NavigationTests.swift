import XCTest

final class NavigationTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testTabBarExists() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    }

    func testNavigationToMovies() throws {
        let moviesTab = app.tabBars.buttons["Movies"]
        XCTAssertTrue(moviesTab.waitForExistence(timeout: 5))
        moviesTab.tap()

        let moviesTitle = app.staticTexts["Movies"]
        XCTAssertTrue(moviesTitle.waitForExistence(timeout: 3))
    }

    func testNavigationToSeries() throws {
        let seriesTab = app.tabBars.buttons["Series"]
        XCTAssertTrue(seriesTab.waitForExistence(timeout: 5))
        seriesTab.tap()

        let seriesTitle = app.staticTexts["Series"]
        XCTAssertTrue(seriesTitle.waitForExistence(timeout: 3))
    }

    func testNavigationToLiveTV() throws {
        let liveTab = app.tabBars.buttons["Live TV"]
        XCTAssertTrue(liveTab.waitForExistence(timeout: 5))
        liveTab.tap()

        let liveTitle = app.staticTexts["Live TV"]
        XCTAssertTrue(liveTitle.waitForExistence(timeout: 3))
    }

    func testNavigationToSettings() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let settingsTitle = app.staticTexts["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3))
    }

    func testAllTabsAreAccessible() throws {
        let tabs = app.tabBars.buttons
        XCTAssertTrue(tabs["Movies"].exists)
        XCTAssertTrue(tabs["Series"].exists)
        XCTAssertTrue(tabs["Live TV"].exists)
        XCTAssertTrue(tabs["Settings"].exists)
    }
}
