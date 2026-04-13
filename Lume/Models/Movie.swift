import Foundation

typealias Movie = LumeSchemaV3.Movie

enum DownloadStatus: String, Codable {
    case pending
    case downloading
    case completed
    case failed
}

extension Movie {
    var downloadStatus: DownloadStatus? {
        get {
            guard let raw = downloadStatusRaw else { return nil }
            return DownloadStatus(rawValue: raw)
        }
        set { downloadStatusRaw = newValue?.rawValue }
    }
}
