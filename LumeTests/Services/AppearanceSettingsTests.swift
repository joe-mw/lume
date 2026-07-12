@testable import Lume
import SwiftUI
import Testing

struct AppearanceSettingsTests {
    @Test func `resolve maps known raw values`() {
        #expect(AppAppearance.resolve("system") == .system)
        #expect(AppAppearance.resolve("dark") == .dark)
        #expect(AppAppearance.resolve("light") == .light)
    }

    @Test func `resolve falls back to system for unknown values`() {
        #expect(AppAppearance.resolve("") == .system)
        #expect(AppAppearance.resolve("sepia") == .system)
    }

    @Test func `color scheme mapping`() {
        #expect(AppAppearance.system.colorScheme == nil)
        #expect(AppAppearance.dark.colorScheme == .dark)
        #expect(AppAppearance.light.colorScheme == .light)
    }

    @Test func `default is system`() {
        #expect(AppAppearance.defaultValue == .system)
    }
}
