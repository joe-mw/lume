import XCTest

/// Tests the initial state when the app launches with a seeded playlist.
/// The login form is bypassed via the -ui-testing launch argument.
final class LoginFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testAppShowsSeededPlaylist() {
        let addPlaylistButton = app.buttons["Add Playlist"]
        // The seeded playlist means the main tabs appear, not the login form
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    func testTabBarShowsAllTabs() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Movies"].exists)
        XCTAssertTrue(app.tabBars.buttons["Series"].exists)
        XCTAssertTrue(app.tabBars.buttons["Live TV"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }

    func testAddPlaylistButtonAvailableInSettings() {
        app.tabBars.buttons["Settings"].tap()
        let addButton = app.buttons["Add Playlist"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
    }

    func testSeededPlaylistNameVisible() {
        app.tabBars.buttons["Settings"].tap()
        let playlistName = app.staticTexts["Test Playlist"]
        XCTAssertTrue(playlistName.waitForExistence(timeout: 3))
    }

    func testPlaylistCanBeDeleted() {
        app.tabBars.buttons["Settings"].tap()
        let playlistName = app.staticTexts["Test Playlist"]
        XCTAssertTrue(playlistName.waitForExistence(timeout: 3))
        playlistName.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
    }

    func testServerConnectionNotVisibleWithSeededData() {
        let header = app.staticTexts["Server Connection"]
        XCTAssertFalse(header.waitForExistence(timeout: 2))
    }
}
