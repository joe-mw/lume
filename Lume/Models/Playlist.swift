import Foundation
import SwiftData

@Model
final class Playlist {
    var id: UUID = UUID()
    var name: String
    var serverURL: String
    var username: String
    var password: String

    var serverTimezone: String?
    var serverVersion: String?

    var userStatus: String?
    var maxConnections: String?
    var activeConnections: String?
    var expDate: String?

    var syncEnabled: Bool = true
    var lastSyncDate: Date?
    var syncStatusRaw: String = "idle"

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

enum SyncStatus: String, Codable {
    case idle
    case syncing
    case error
}

extension Playlist {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }
}
