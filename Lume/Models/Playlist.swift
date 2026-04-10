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
