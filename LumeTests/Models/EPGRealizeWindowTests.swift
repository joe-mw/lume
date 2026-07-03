import CoreGraphics
import Foundation
@testable import Lume
import Testing

struct EPGRealizeWindowTests {
    @Test func `window covers the viewport plus one block on each side, snapped to blocks`() {
        let window = EPGRealizeWindow.around(offsetX: 4400, viewportWidth: 1680, blockWidth: 360)
        #expect(window.startX == 3960)
        #expect(window.endX == 6480)
    }

    @Test func `window clamps to zero at the leading edge`() {
        let window = EPGRealizeWindow.around(offsetX: 0, viewportWidth: 1680, blockWidth: 360)
        #expect(window.startX == 0)
        #expect(window.endX == 2160)
    }

    @Test func `window is stable between block crossings`() {
        let blockWidth: CGFloat = 360
        let base = EPGRealizeWindow.around(offsetX: 800, viewportWidth: 1800, blockWidth: blockWidth)
        let withinBlock = EPGRealizeWindow.around(offsetX: 1000, viewportWidth: 1800, blockWidth: blockWidth)
        let nextBlock = EPGRealizeWindow.around(offsetX: 1100, viewportWidth: 1800, blockWidth: blockWidth)
        #expect(base == withinBlock)
        #expect(base != nextBlock)
    }
}
