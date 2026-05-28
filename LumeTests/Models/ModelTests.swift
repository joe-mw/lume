import Testing
import Foundation
import SwiftData
@testable import Lume

struct ModelTests {

    // MARK: - ModelContainer Setup

    @Test func modelContainerCreatesSuccessfully() throws {
        let container = try makeTestContainer()
        let entityNames = container.schema.entities.map(\.name)
        #expect(entityNames.contains("Playlist"))
        #expect(entityNames.contains("Category"))
        #expect(entityNames.contains("Movie"))
        #expect(entityNames.contains("Series"))
        #expect(entityNames.contains("Episode"))
        #expect(entityNames.contains("LiveStream"))
        #expect(entityNames.contains("EPGListing"))
    }

    // MARK: - Category

    @Test func categoryIDConstruction() {
        let playlist = Playlist(name: "P", serverURL: "http://x.com", username: "u", password: "p")
        let category = Lume.Category(apiId: "42", name: "Action", parentId: 0, type: .vod, playlist: playlist)
        let expectedPrefix = "\(playlist.id.uuidString)-vod-42"
        #expect(category.id == expectedPrefix)
        #expect(category.apiId == "42")
        #expect(category.name == "Action")
        #expect(category.type == .vod)
        #expect(category.playlist?.id == playlist.id)
    }

    @Test func categoryTypeRoundTrip() {
        let playlist = Playlist(name: "P", serverURL: "http://x.com", username: "u", password: "p")
        let live = Lume.Category(apiId: "1", name: "Live", parentId: 0, type: .live, playlist: playlist)
        #expect(live.type == .live)
        #expect(live.typeRaw == "live")

        live.type = .series
        #expect(live.type == .series)
        #expect(live.typeRaw == "series")
    }

    @Test func categoryUpsertViaUniqueAttribute() throws {
        let container = try makeTestContainer()
        let playlist = Playlist(name: "P", serverURL: "http://x.com", username: "u", password: "p")

        let ctx1 = ModelContext(container)
        ctx1.autosaveEnabled = false
        let cat = Lume.Category(apiId: "1", name: "Original", parentId: 0, type: .vod, playlist: playlist)
        ctx1.insert(cat)
        try ctx1.save()

        let ctx2 = ModelContext(container)
        ctx2.autosaveEnabled = false
        let cat2 = Lume.Category(apiId: "1", name: "Updated", parentId: 0, type: .vod, playlist: playlist)
        cat2.id = cat.id  // Same unique ID
        ctx2.insert(cat2)
        try ctx2.save()

        let expectedApiId = "1"
        let fetch = FetchDescriptor<Lume.Category>(predicate: #Predicate { $0.apiId == expectedApiId })
        let results = try ctx2.fetch(fetch)
        #expect(results.count == 1)
    }

    // MARK: - Movie

    @Test func movieDownloadStatusRoundTrip() {
        let movie = Movie(id: "m-1", streamId: 1, name: "Test")
        #expect(movie.downloadStatus == nil)

        movie.downloadStatus = .downloading
        #expect(movie.downloadStatus == .downloading)
        #expect(movie.downloadStatusRaw == "downloading")

        movie.downloadStatus = .completed
        #expect(movie.downloadStatus == .completed)
    }

    @Test func movieFavoriteAndWatchTracking() {
        let movie = Movie(id: "m-2", streamId: 2, name: "Tracked")
        #expect(movie.isFavorite == false)
        #expect(movie.isWatched == false)
        #expect(movie.watchProgress == 0)

        movie.isFavorite = true
        #expect(movie.isFavorite == true)

        movie.watchProgress = 500
        movie.isWatched = true
        #expect(movie.watchProgress == 500)
        #expect(movie.isWatched == true)
    }

    @Test func movieTMDBCoercion() {
        let movie = Movie(id: "m-3", streamId: 3, name: "TMDB", tmdb: "12345")
        movie.tmdbId = Int(movie.tmdb ?? "")
        #expect(movie.tmdbId == 12345)
    }

    // MARK: - Episode

    @Test func episodeDownloadStatusRoundTrip() {
        let episode = Episode(id: "e-1", episodeId: "1", title: "Ep1",
                              containerExtension: "mp4", seasonNum: 1, episodeNum: 1)
        #expect(episode.downloadStatus == nil)

        episode.downloadStatus = .failed
        #expect(episode.downloadStatus == .failed)
        #expect(episode.downloadStatusRaw == "failed")
    }

    @Test func episodeWatchProgress() {
        let episode = Episode(id: "e-2", episodeId: "2", title: "Ep2",
                              containerExtension: "mkv", seasonNum: 2, episodeNum: 3)
        #expect(episode.watchProgress == 0)
        episode.watchProgress = 3600
        #expect(episode.watchProgress == 3600)
    }

    // MARK: - Playlist

    @Test func playlistSyncStatusRoundTrip() {
        let playlist = Playlist(name: "Test", serverURL: "http://x.com", username: "u", password: "p")
        #expect(playlist.syncStatus == .idle)
        #expect(playlist.syncStatusRaw == "idle")

        playlist.syncStatus = .syncing
        #expect(playlist.syncStatus == .syncing)

        playlist.syncStatus = .error
        #expect(playlist.syncStatus == .error)
    }

    @Test func playlistDefaultValues() {
        let playlist = Playlist(name: "Test", serverURL: "http://x.com", username: "u", password: "p")
        #expect(playlist.syncEnabled == true)
        #expect(playlist.categories.isEmpty)
        #expect(playlist.addedAt.timeIntervalSinceNow < 1)  // Created recently
    }

    // MARK: - Series

    @Test func seriesDefaultValues() {
        let series = Series(id: "s-1", seriesId: 1, name: "Series")
        #expect(series.isFavorite == false)
        #expect(series.episodes.isEmpty)
    }

    // MARK: - LiveStream

    @Test func liveStreamDefaultValues() {
        let stream = LiveStream(id: "l-1", streamId: 1, name: "Channel")
        #expect(stream.isFavorite == false)
        #expect(stream.epgListings.isEmpty)
        #expect(stream.tvArchive == 0)
        #expect(stream.tvArchiveDuration == 0)
    }
}
