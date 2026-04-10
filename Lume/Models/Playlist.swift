import Foundation
import SwiftData

@Model
final class Playlist {
    var id: UUID = UUID()
    var name: String
    var serverURL: String
    var username: String
    var password: String

    // Server info from auth
    var serverTimezone: String?
    var serverVersion: String?

    // User info
    var userStatus: String?
    var maxConnections: String?
    var activeConnections: String?
    var expDate: String?

    // Sync support
    var syncEnabled: Bool = true
    var lastSyncDate: Date?
    var syncStatusRaw: String = "idle" // idle, syncing, error

    // Relationships
    @Relationship(deleteRule: .cascade) var categories: [Category] = []

    var addedAt: Date = Date()
    var lastUpdated: Date?

    init(name: String, serverURL: String, username: String, password: String) {
        self.name = name
        self.serverURL = serverURL
        self.username = username
        self.password = password
    }
}

// MARK: - Extensions

extension Playlist {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }
}

// MARK: - Supporting Types

enum SyncStatus: String, Codable {
    case idle
    case syncing
    case error
}
