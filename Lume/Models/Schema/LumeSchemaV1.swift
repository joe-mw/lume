//
//  LumeSchemaV1.swift
//  Lume
//
//  Schema Version 1 - Initial Schema
//

import Foundation
import SwiftData

enum LumeSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Playlist.self,
            Category.self,
            LiveStream.self,
            Movie.self,
            Series.self,
            Episode.self,
            EPGListing.self
        ]
    }

    // V1 Models (current state)
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

        init(apiId: String, name: String, parentId: Int, typeRaw: String, playlist: Playlist? = nil) {
            self.id = "\(playlist?.id.uuidString ?? "unknown")-\(typeRaw)-\(apiId)"
            self.apiId = apiId
            self.name = name
            self.parentId = parentId
            self.typeRaw = typeRaw
            self.playlist = playlist
        }
    }

    @Model
    final class LiveStream {
        @Attribute(.unique) var id: String
        var streamId: Int
        var name: String
        var streamIcon: String?
        var epgChannelId: String?
        var num: Int
        var tvArchive: Int
        var tvArchiveDuration: Int

        var category: Category?

        init(id: String, streamId: Int, name: String, streamIcon: String? = nil, epgChannelId: String? = nil, num: Int = 0, tvArchive: Int = 0, tvArchiveDuration: Int = 0, category: Category? = nil) {
            self.id = id
            self.streamId = streamId
            self.name = name
            self.streamIcon = streamIcon
            self.epgChannelId = epgChannelId
            self.num = num
            self.tvArchive = tvArchive
            self.tvArchiveDuration = tvArchiveDuration
            self.category = category
        }
    }

    @Model
    final class Movie {
        @Attribute(.unique) var id: String
        var streamId: Int
        var name: String
        var streamIcon: String?
        var rating: Double
        var rating5Based: Double
        var added: String?
        var containerExtension: String?
        var tmdb: String?
        var num: Int
        var isAdult: Int

        // Metadata
        var director: String?
        var actors: String?
        var plot: String?
        var genre: String?
        var releaseDate: String?
        var durationSecs: Int?
        var youtubeTrailer: String?

        var category: Category?

        var isFavorite: Bool = false
        var watchProgress: Double = 0.0
        var isWatched: Bool = false

        init(id: String, streamId: Int, name: String, streamIcon: String? = nil, rating: Double = 0, rating5Based: Double = 0, added: String? = nil, containerExtension: String? = nil, tmdb: String? = nil, num: Int = 0, isAdult: Int = 0, category: Category? = nil) {
            self.id = id
            self.streamId = streamId
            self.name = name
            self.streamIcon = streamIcon
            self.rating = rating
            self.rating5Based = rating5Based
            self.added = added
            self.containerExtension = containerExtension
            self.tmdb = tmdb
            self.num = num
            self.isAdult = isAdult
            self.category = category
        }
    }

    @Model
    final class Series {
        @Attribute(.unique) var id: String
        var seriesId: Int
        var name: String
        var cover: String?
        var plot: String?
        var cast: String?
        var director: String?
        var genre: String?
        var releaseDate: String?
        var lastModified: String?
        var rating: String?
        var rating5Based: String?
        var tmdb: String?
        var num: Int

        var category: Category?
        @Relationship(deleteRule: .cascade) var episodes: [Episode] = []

        var isFavorite: Bool = false

        init(id: String, seriesId: Int, name: String, cover: String? = nil, plot: String? = nil, cast: String? = nil, director: String? = nil, genre: String? = nil, releaseDate: String? = nil, lastModified: String? = nil, rating: String? = nil, rating5Based: String? = nil, tmdb: String? = nil, num: Int = 0, category: Category? = nil) {
            self.id = id
            self.seriesId = seriesId
            self.name = name
            self.cover = cover
            self.plot = plot
            self.cast = cast
            self.director = director
            self.genre = genre
            self.releaseDate = releaseDate
            self.lastModified = lastModified
            self.rating = rating
            self.rating5Based = rating5Based
            self.tmdb = tmdb
            self.num = num
            self.category = category
        }
    }

    @Model
    final class Episode {
        @Attribute(.unique) var id: String
        var episodeId: String
        var episodeNum: Int
        var title: String
        var containerExtension: String
        var season: Int
        var airDate: String?
        var rating: Double
        var plot: String?

        var series: Series?

        init(id: String, episodeId: String, episodeNum: Int, title: String, containerExtension: String, season: Int, airDate: String? = nil, rating: Double = 0, plot: String? = nil, series: Series? = nil) {
            self.id = id
            self.episodeId = episodeId
            self.episodeNum = episodeNum
            self.title = title
            self.containerExtension = containerExtension
            self.season = season
            self.airDate = airDate
            self.rating = rating
            self.plot = plot
            self.series = series
        }
    }

    @Model
    final class EPGListing {
        @Attribute(.unique) var id: String
        var streamId: Int
        var title: String
        var start: Date
        var end: Date
        var desc: String?

        init(id: String, streamId: Int, title: String, start: Date, end: Date, desc: String? = nil) {
            self.id = id
            self.streamId = streamId
            self.title = title
            self.start = start
            self.end = end
            self.desc = desc
        }
    }
}
