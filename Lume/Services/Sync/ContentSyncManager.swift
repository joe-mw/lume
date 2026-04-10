//
//  ContentSyncManager.swift
//  Lume
//
//  Manages content synchronization from Xtream API to SwiftData
//

import Foundation
import SwiftData

// MARK: - ContentSyncManager

actor ContentSyncManager {
    // MARK: - Properties

    private let modelContext: ModelContext
    private let xtreamClient: XtreamClient
    private var activeSyncTasks: [UUID: Task<Void, Error>] = [:]

    // MARK: - Initialization

    init(modelContext: ModelContext, xtreamClient: XtreamClient = XtreamClient()) {
        self.modelContext = modelContext
        self.xtreamClient = xtreamClient
    }

    // MARK: - Playlist Sync

    /// Performs a full sync of a playlist (categories and content)
    func syncPlaylist(_ playlist: Playlist, full: Bool = false) async throws {
        // Prevent concurrent syncs of the same playlist
        guard activeSyncTasks[playlist.id] == nil else {
            throw SyncError.syncInProgress
        }

        let task = Task {
            do {
                playlist.syncStatus = .syncing
                try modelContext.save()

                // Fetch server info to validate credentials
                let authResponse = try await xtreamClient.getInfo(playlist: playlist)

                // Update playlist with server info
                await updatePlaylistInfo(playlist, with: authResponse)

                // Sync all categories
                try await syncAllCategories(for: playlist, full: full)

                playlist.syncStatus = .idle
                playlist.lastSyncDate = Date()
                try modelContext.save()
            } catch {
                playlist.syncStatus = .error
                try? modelContext.save()
                throw error
            }
        }

        activeSyncTasks[playlist.id] = task

        do {
            try await task.value
        } catch {
            throw error
        }

        activeSyncTasks.removeValue(forKey: playlist.id)
    }

    /// Syncs all categories for a playlist
    func syncAllCategories(for playlist: Playlist, full: Bool = false) async throws {
        // Sync VOD categories and content
        try await syncVODCategories(for: playlist)

        // Sync Series categories and content
        try await syncSeriesCategories(for: playlist)

        // Sync Live TV categories and content
        try await syncLiveCategories(for: playlist)
    }

    // MARK: - Category Sync

    /// Syncs VOD (Movies) categories
    private func syncVODCategories(for playlist: Playlist) async throws {
        let categories = try await xtreamClient.getVODCategories(playlist: playlist)

        for categoryDTO in categories {
            let category = await findOrCreateCategory(
                apiId: categoryDTO.categoryId,
                name: categoryDTO.categoryName,
                parentId: categoryDTO.parentId ?? 0,
                type: .vod,
                playlist: playlist
            )

            category.lastRefreshed = Date()

            // Sync movies for this category
            try await syncMovies(for: category, playlist: playlist)
        }

        try modelContext.save()
    }

    /// Syncs Series categories
    private func syncSeriesCategories(for playlist: Playlist) async throws {
        let categories = try await xtreamClient.getSeriesCategories(playlist: playlist)

        for categoryDTO in categories {
            let category = await findOrCreateCategory(
                apiId: categoryDTO.categoryId,
                name: categoryDTO.categoryName,
                parentId: categoryDTO.parentId ?? 0,
                type: .series,
                playlist: playlist
            )

            category.lastRefreshed = Date()

            // Sync series for this category
            try await syncSeries(for: category, playlist: playlist)
        }

        try modelContext.save()
    }

    /// Syncs Live TV categories
    private func syncLiveCategories(for playlist: Playlist) async throws {
        let categories = try await xtreamClient.getLiveCategories(playlist: playlist)

        for categoryDTO in categories {
            let category = await findOrCreateCategory(
                apiId: categoryDTO.categoryId,
                name: categoryDTO.categoryName,
                parentId: categoryDTO.parentId ?? 0,
                type: .live,
                playlist: playlist
            )

            category.lastRefreshed = Date()

            // Sync live streams for this category
            try await syncLiveStreams(for: category, playlist: playlist)
        }

        try modelContext.save()
    }

    // MARK: - Content Sync

    /// Syncs movies for a category
    func syncMovies(for category: Category, playlist: Playlist) async throws {
        let streams = try await xtreamClient.getVODStreams(playlist: playlist, categoryId: category.apiId)

        for streamDTO in streams {
            guard let streamId = streamDTO.streamId else { continue }
            let movieId = "\(playlist.id.uuidString)-movie-\(streamId)"

            let movie = await findOrCreateMovie(id: movieId, streamId: streamId, category: category)

            // Update movie properties
            movie.name = streamDTO.name ?? ""
            movie.streamIcon = streamDTO.streamIcon
            movie.rating = streamDTO.rating ?? 0
            movie.rating5Based = streamDTO.rating5Based ?? 0
            movie.added = streamDTO.added
            movie.containerExtension = streamDTO.containerExtension
            movie.tmdb = streamDTO.tmdb
            movie.num = streamDTO.num ?? 0
            movie.isAdult = streamDTO.isAdult ?? 0

            // Store TMDB ID if available
            if let tmdbString = streamDTO.tmdb, let tmdbInt = Int(tmdbString) {
                movie.tmdbId = tmdbInt
            }
        }

        try modelContext.save()
    }

    /// Syncs series for a category
    func syncSeries(for category: Category, playlist: Playlist) async throws {
        let seriesList = try await xtreamClient.getSeries(playlist: playlist, categoryId: category.apiId)

        for seriesDTO in seriesList {
            guard let seriesId = seriesDTO.seriesId else { continue }
            let id = "\(playlist.id.uuidString)-series-\(seriesId)"

            let series = await findOrCreateSeries(id: id, seriesId: seriesId, category: category)

            // Update series properties
            series.name = seriesDTO.name ?? ""
            series.cover = seriesDTO.cover
            series.plot = seriesDTO.plot
            series.cast = seriesDTO.cast
            series.director = seriesDTO.director
            series.genre = seriesDTO.genre
            series.releaseDate = seriesDTO.releaseDate
            series.lastModified = seriesDTO.lastModified
            series.rating = seriesDTO.rating
            series.rating5Based = seriesDTO.rating5Based
            series.tmdb = seriesDTO.tmdb
            series.num = seriesDTO.num ?? 0

            // Store TMDB ID if available
            if let tmdbString = seriesDTO.tmdb, let tmdbInt = Int(tmdbString) {
                series.tmdbId = tmdbInt
            }
        }

        try modelContext.save()
    }

    /// Syncs episodes for a series
    func syncEpisodes(for series: Series, playlist: Playlist) async throws {
        let seriesInfo = try await xtreamClient.getSeriesInfo(playlist: playlist, seriesId: series.seriesId)

        // Parse episodes by season
        guard let episodesDict = seriesInfo.episodes else { return }

        for (seasonKey, episodes) in episodesDict {
            guard let seasonNum = Int(seasonKey) else { continue }

            for episodeDTO in episodes {
                guard let episodeIdString = episodeDTO.id else { continue }
                let episodeId = "\(series.id)-episode-\(episodeIdString)"

                let episode = await findOrCreateEpisode(
                    id: episodeId,
                    episodeIdString: episodeIdString,
                    series: series
                )

                // Update episode properties
                episode.title = episodeDTO.title ?? ""
                episode.containerExtension = episodeDTO.containerExtension ?? "mkv"
                episode.seasonNum = seasonNum
                episode.episodeNum = episodeDTO.episodeNum ?? 0
                episode.added = episodeDTO.added
                episode.directSource = episodeDTO.directSource

                // Episode info
                if let info = episodeDTO.info {
                    episode.durationSecs = info.durationSecs
                    episode.movieImage = info.movieImage
                    episode.rating = info.rating
                    episode.airDate = info.airDate
                }
            }
        }

        try modelContext.save()
    }

    /// Syncs live streams for a category
    func syncLiveStreams(for category: Category, playlist: Playlist) async throws {
        let streams = try await xtreamClient.getLiveStreams(playlist: playlist, categoryId: category.apiId)

        for streamDTO in streams {
            guard let streamId = streamDTO.streamId else { continue }
            let id = "\(playlist.id.uuidString)-live-\(streamId)"

            let liveStream = await findOrCreateLiveStream(
                id: id,
                streamId: streamId,
                category: category
            )

            // Update live stream properties
            liveStream.name = streamDTO.name ?? ""
            liveStream.streamIcon = streamDTO.streamIcon
            liveStream.epgChannelId = streamDTO.epgChannelId
            liveStream.added = streamDTO.added
            liveStream.customSid = streamDTO.customSid
            liveStream.tvArchive = streamDTO.tvArchive ?? 0
            liveStream.tvArchiveDuration = streamDTO.tvArchiveDuration ?? 0
            liveStream.isAdult = streamDTO.isAdult ?? 0
            liveStream.num = streamDTO.num ?? 0
        }

        try modelContext.save()
    }

    // MARK: - Helper Methods

    private func updatePlaylistInfo(_ playlist: Playlist, with authResponse: XtreamAuthResponse) {
        playlist.userStatus = authResponse.userInfo.status
        playlist.maxConnections = authResponse.userInfo.maxConnections
        playlist.activeConnections = authResponse.userInfo.activeCons
        playlist.expDate = authResponse.userInfo.expDate
        playlist.serverTimezone = authResponse.serverInfo.timezone
        playlist.lastUpdated = Date()
    }

    private func findOrCreateCategory(
        apiId: String,
        name: String,
        parentId: Int,
        type: CategoryType,
        playlist: Playlist
    ) async -> Category {
        let id = "\(playlist.id.uuidString)-\(type.rawValue)-\(apiId)"

        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.id == id }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let category = Category(
            apiId: apiId,
            name: name,
            parentId: parentId,
            type: type,
            playlist: playlist
        )
        modelContext.insert(category)
        return category
    }

    private func findOrCreateMovie(id: String, streamId: Int, category: Category) async -> Movie {
        let descriptor = FetchDescriptor<Movie>(
            predicate: #Predicate { $0.id == id }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let movie = Movie(
            id: id,
            streamId: streamId,
            name: "",
            category: category
        )
        modelContext.insert(movie)
        return movie
    }

    private func findOrCreateSeries(id: String, seriesId: Int, category: Category) async -> Series {
        let descriptor = FetchDescriptor<Series>(
            predicate: #Predicate { $0.id == id }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let series = Series(
            id: id,
            seriesId: seriesId,
            name: "",
            category: category
        )
        modelContext.insert(series)
        return series
    }

    private func findOrCreateEpisode(
        id: String,
        episodeIdString: String,
        series: Series
    ) async -> Episode {
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate { $0.id == id }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let episode = Episode(
            id: id,
            episodeId: episodeIdString,
            title: "",
            containerExtension: "mkv",
            seasonNum: 1,
            episodeNum: 1,
            series: series
        )
        modelContext.insert(episode)
        return episode
    }

    private func findOrCreateLiveStream(
        id: String,
        streamId: Int,
        category: Category
    ) async -> LiveStream {
        let descriptor = FetchDescriptor<LiveStream>(
            predicate: #Predicate { $0.id == id }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let liveStream = LiveStream(
            id: id,
            streamId: streamId,
            name: "",
            category: category
        )
        modelContext.insert(liveStream)
        return liveStream
    }
}

// MARK: - Sync Error

enum SyncError: LocalizedError {
    case syncInProgress
    case invalidCredentials
    case networkError(Error)
    case databaseError(Error)

    var errorDescription: String? {
        switch self {
        case .syncInProgress:
            return "A sync is already in progress for this playlist"
        case .invalidCredentials:
            return "Invalid username or password"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}
