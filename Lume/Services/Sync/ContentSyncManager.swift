//
//  ContentSyncManager.swift
//  Lume
//
//  Manages content synchronization from Xtream API to SwiftData
//

import Foundation
import SwiftData
import OSLog

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

                // Sync all content (movies, series, live streams)
                try await syncMovies(for: playlist)
                // try await syncSeries(for: playlist)
                // try await syncLiveStreams(for: playlist)

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
        Logger.database.info("Completed sync for playlist \(playlist.name)")
    }

    /// Syncs all categories for a playlist
    func syncAllCategories(for playlist: Playlist, full: Bool = false) async throws {
        // Sync VOD categories and content
        Logger.database.info("Starting VOD category sync for playlist \(playlist.name)")
        try await syncVODCategories(for: playlist)

        // Sync Series categories and content
        Logger.database.info("Starting Series category sync for playlist \(playlist.name)")
        try await syncSeriesCategories(for: playlist)

        // Sync Live TV categories and content
        Logger.database.info("Starting Live TV category sync for playlist \(playlist.name)")
        try await syncLiveCategories(for: playlist)
    }

    // MARK: - Category Sync

    /// Syncs VOD (Movies) categories
    private func syncVODCategories(for playlist: Playlist) async throws {
        let categories = try await xtreamClient.getVODCategories(playlist: playlist)

        Logger.database.info("Fetched \(categories.count) VOD categories for playlist \(playlist.name)")

        for categoryDTO in categories {
            let category = await createCategory(
                apiId: categoryDTO.categoryId,
                name: categoryDTO.categoryName,
                parentId: categoryDTO.parentId ?? 0,
                type: .vod,
                playlist: playlist
            )

            category.lastRefreshed = Date()

        }

        try modelContext.save()
    }

    /// Syncs Series categories
    private func syncSeriesCategories(for playlist: Playlist) async throws {
        let categories = try await xtreamClient.getSeriesCategories(playlist: playlist)

        for categoryDTO in categories {
            let category = await createCategory(
                apiId: categoryDTO.categoryId,
                name: categoryDTO.categoryName,
                parentId: categoryDTO.parentId ?? 0,
                type: .series,
                playlist: playlist
            )

            category.lastRefreshed = Date()
        }

        try modelContext.save()
    }

    /// Syncs Live TV categories
    private func syncLiveCategories(for playlist: Playlist) async throws {
        let categories = try await xtreamClient.getLiveCategories(playlist: playlist)

        for categoryDTO in categories {
            let category = await createCategory(
                apiId: categoryDTO.categoryId,
                name: categoryDTO.categoryName,
                parentId: categoryDTO.parentId ?? 0,
                type: .live,
                playlist: playlist
            )

            category.lastRefreshed = Date()
        }

        try modelContext.save()
    }

    // MARK: - Content Sync

    /// Syncs movies
    func syncMovies(for playlist: Playlist) async throws {
        let movies = try await xtreamClient.getVODStreams(playlist: playlist)

        Logger.database.info("Fetched \(movies.count) movies for playlist \(playlist.name)")

        for movieDTO in movies {
            guard let streamId = movieDTO.streamId else { continue }
            let movieId = "\(playlist.id.uuidString)-movie-\(streamId)"

            let movie = Movie(
                id: movieId,
                streamId: streamId,
                name: ""
            )

            // Update movie properties
            movie.name = movieDTO.name ?? ""
            movie.streamIcon = movieDTO.streamIcon
            movie.rating = movieDTO.rating ?? 0
            movie.rating5Based = movieDTO.rating5Based ?? 0
            movie.added = movieDTO.added
            movie.containerExtension = movieDTO.containerExtension
            movie.tmdb = movieDTO.tmdb
            movie.num = movieDTO.num ?? 0
            movie.isAdult = movieDTO.isAdult ?? 0

            // Assign category if available
            if let categoryId = movieDTO.categoryId {
                movie.category = findCategory(
                    apiId: categoryId,
                    type: .vod,
                    playlist: playlist
                )
            }

            // Store TMDB ID if available
            if let tmdbString = movieDTO.tmdb, let tmdbInt = Int(tmdbString) {
                movie.tmdbId = tmdbInt
            }

            modelContext.insert(movie)
        }

        Logger.database.info("Completed syncing movies for playlist \(playlist.name)")

        try modelContext.save()
    }

    /// Syncs series
    func syncSeries(for playlist: Playlist) async throws {
        let seriesList = try await xtreamClient.getSeries(playlist: playlist)

        for seriesDTO in seriesList {
            guard let seriesId = seriesDTO.seriesId else { continue }
            let id = "\(playlist.id.uuidString)-series-\(seriesId)"

            let series = Series(
                id: id,
                seriesId: seriesId,
                name: ""
            )

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

            // Assign category if available
            if let categoryId = seriesDTO.categoryId {
                series.category = findCategory(
                    apiId: categoryId,
                    type: .series,
                    playlist: playlist
                )
            }

            // Store TMDB ID if available
            if let tmdbString = seriesDTO.tmdb, let tmdbInt = Int(tmdbString) {
                series.tmdbId = tmdbInt
            }

            modelContext.insert(series)
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

                let episode = Episode(
                    id: episodeId,
                    episodeId: episodeIdString,
                    title: "",
                    containerExtension: "mkv",
                    seasonNum: seasonNum,
                    episodeNum: episodeDTO.episodeNum ?? 0,
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

                modelContext.insert(episode)
            }
        }

        try modelContext.save()
    }

    /// Syncs live streams
    func syncLiveStreams(for playlist: Playlist) async throws {
        let streams = try await xtreamClient.getLiveStreams(playlist: playlist)

        for streamDTO in streams {
            guard let streamId = streamDTO.streamId else { continue }
            let id = "\(playlist.id.uuidString)-live-\(streamId)"

            let liveStream = LiveStream(
                id: id,
                streamId: streamId,
                name: ""
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

            // Assign category if available
            if let categoryId = streamDTO.categoryId {
                liveStream.category = findCategory(
                    apiId: categoryId,
                    type: .live,
                    playlist: playlist
                )
            }

            modelContext.insert(liveStream)
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

    private func createCategory(
        apiId: String,
        name: String,
        parentId: Int,
        type: CategoryType,
        playlist: Playlist
    ) async -> Category {
        // Check if category already exists
        if let existing = findCategory(apiId: apiId, type: type, playlist: playlist) {
            // Update existing category
            existing.name = name
            existing.parentId = parentId
            return existing
        }

        // Create new category
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

    /// Finds a category by API ID and type for a specific playlist
    private func findCategory(
        apiId: String,
        type: CategoryType,
        playlist: Playlist
    ) -> Category? {
        let playlistId = playlist.id
        let typeRaw = type.rawValue

        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { category in
                category.apiId == apiId &&
                category.typeRaw == typeRaw &&
                category.playlist != nil &&
                category.playlist!.id == playlistId
            }
        )

        return try? modelContext.fetch(descriptor).first
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
