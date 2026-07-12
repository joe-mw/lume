//
//  AppearanceSettings.swift
//  Lume
//
//  The user's app-wide appearance override (System / Dark / Light). Persisted
//  as a plain string and applied at the scene root via `.preferredColorScheme`,
//  so a device in Light Mode can still run Lume permanently dark (and vice
//  versa). `system` keeps the previous follow-the-device behaviour.
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    static let storageKey = "app.appearance"
    static let defaultValue: AppAppearance = .system

    /// Resolves a persisted raw value, falling back to `system` for missing
    /// or unknown values.
    static func resolve(_ raw: String) -> AppAppearance {
        AppAppearance(rawValue: raw) ?? defaultValue
    }

    var id: String {
        rawValue
    }

    /// The scheme handed to `.preferredColorScheme`; `nil` follows the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    /// Localized plain-string label for surfaces that can't take a
    /// `LocalizedStringKey` (the tvOS cycle row).
    var label: String {
        switch self {
        case .system: String(localized: "System")
        case .dark: String(localized: "Dark")
        case .light: String(localized: "Light")
        }
    }
}
