import Foundation
import SwiftData

enum CategoryType: String, Codable {
    case live
    case vod
    case series
}

@Model
final class Category {
    @Attribute(.unique) var id: String
    var apiId: String
    var name: String
    var parentId: Int
    var typeRaw: String
    var playlist: Playlist?
    
    // Relationships
    @Relationship(deleteRule: .cascade) var liveStreams: [LiveStream] = []
    @Relationship(deleteRule: .cascade) var movies: [Movie] = []
    @Relationship(deleteRule: .cascade) var series: [Series] = []

    var type: CategoryType {
        get { CategoryType(rawValue: typeRaw) ?? .live }
        set { typeRaw = newValue.rawValue }
    }
    
    init(apiId: String, name: String, parentId: Int, type: CategoryType, playlist: Playlist? = nil) {
        self.id = "\(playlist?.id.uuidString ?? "unknown")-\(type.rawValue)-\(apiId)"
        self.apiId = apiId
        self.name = name
        self.parentId = parentId
        self.typeRaw = type.rawValue
        self.playlist = playlist
    }
}
