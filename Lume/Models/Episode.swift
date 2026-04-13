import Foundation
import SwiftData

@Model
final class Episode {
    @Attribute(.unique) var id: String
    var episodeId: String
    var title: String
    var containerExtension: String
    var seasonNum: Int
    var episodeNum: Int
    var added: String?
    var directSource: String?

    var durationSecs: Int?
    var movieImage: String?
    var plot: String?
    var rating: Double?
    var airDate: String?

    var series: Series?

    var watchProgress: Double = 0.0
    var isWatched: Bool = false

    var downloadStatusRaw: String?
    var localFileURL: String?
    var downloadedAt: Date?
    var lastWatchedDate: Date?

    init(
        id: String,
        episodeId: String,
        title: String,
        containerExtension: String,
        seasonNum: Int,
        episodeNum: Int,
        added: String? = nil,
        directSource: String? = nil,
        series: Series? = nil
    ) {
        self.id = id
        self.episodeId = episodeId
        self.title = title
        self.containerExtension = containerExtension
        self.seasonNum = seasonNum
        self.episodeNum = episodeNum
        self.added = added
        self.directSource = directSource
        self.series = series
    }
}

extension Episode {
    var downloadStatus: DownloadStatus? {
        get {
            guard let raw = downloadStatusRaw else { return nil }
            return DownloadStatus(rawValue: raw)
        }
        set { downloadStatusRaw = newValue?.rawValue }
    }
}
