import Foundation

enum CategoryType: String, Codable {
    case live
    case vod
    case series
}

typealias Category = LumeSchemaV3.Category

extension Category {
    var type: CategoryType {
        get { CategoryType(rawValue: typeRaw) ?? .live }
        set { typeRaw = newValue.rawValue }
    }

    convenience init(apiId: String, name: String, parentId: Int, type: CategoryType, playlist: Playlist? = nil) {
        self.init(apiId: apiId, name: name, parentId: parentId, typeRaw: type.rawValue, playlist: playlist)
    }
}
