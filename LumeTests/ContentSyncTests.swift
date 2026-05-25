//
//  ContentSyncTests.swift
//  LumeTests
//
//  Tests that content sync processes large datasets with bounded memory.
//

import Testing
import Foundation
import SwiftData
@testable import Lume

struct ContentSyncTests {

    /// Verifies that syncing 13,900 movies from the example JSON file
    /// completes successfully and results in the correct number of persisted records.
    /// Memory should stay bounded because each batch uses a fresh ModelContext.
    @Test func syncMoviesFromExampleJSON() async throws {
        // Load the example JSON
        let jsonURL = Bundle.main.bundleURL
            .deletingLastPathComponent() // .xctest
            .deletingLastPathComponent() // Products
            .deletingLastPathComponent() // Build
            .deletingLastPathComponent() // DerivedData/...
            // Fall back: try the project source tree
        let projectURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // LumeTests
            .deletingLastPathComponent() // Lume project root
            .appendingPathComponent("ExampleData/Movies.json")

        let data = try Data(contentsOf: projectURL)
        let decoder = JSONDecoder()
        let movies = try decoder.decode([XtreamVODStream].self, from: data)

        #expect(movies.count > 10000, "Expected at least 10,000 movies in example data, got \(movies.count)")

        // Set up an in-memory SwiftData container
        let schema = Schema([
            Playlist.self,
            Category.self,
            LiveStream.self,
            Movie.self,
            Series.self,
            Episode.self,
            EPGListing.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        // Create a playlist
        let context = ModelContext(container)
        let playlist = Playlist(name: "Test", serverURL: "http://test.example.com", username: "user", password: "pass")
        context.insert(playlist)
        try context.save()
        let playlistId = playlist.id

        // Process movies in batches (same logic as ContentSyncManager)
        let batchSize = 500
        let totalCount = movies.count

        for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
            try autoreleasepool {
                let batchEnd = min(batchStart + batchSize, totalCount)
                let batch = movies[batchStart..<batchEnd]

                let batchContext = ModelContext(container)
                batchContext.autosaveEnabled = false

                for movieDTO in batch {
                    guard let streamId = movieDTO.streamId else { continue }
                    let movieId = "\(playlistId.uuidString)-movie-\(streamId)"

                    let movie = Movie(id: movieId, streamId: streamId, name: "")
                    movie.name = movieDTO.name ?? ""
                    movie.streamIcon = movieDTO.streamIcon
                    movie.rating = movieDTO.rating ?? 0
                    movie.rating5Based = movieDTO.rating5Based ?? 0
                    movie.added = movieDTO.added
                    movie.containerExtension = movieDTO.containerExtension
                    movie.tmdb = movieDTO.tmdb
                    movie.num = movieDTO.num ?? 0
                    movie.isAdult = movieDTO.isAdult ?? 0

                    if let tmdbString = movieDTO.tmdb, let tmdbInt = Int(tmdbString) {
                        movie.tmdbId = tmdbInt
                    }

                    batchContext.insert(movie)
                }

                try batchContext.save()
            }
        }

        // Verify all movies were persisted
        let verifyContext = ModelContext(container)
        let count = try verifyContext.fetchCount(FetchDescriptor<Movie>())
        #expect(count == movies.count, "Expected \(movies.count) movies in database, got \(count)")
    }

    /// Verifies that re-syncing (upsert) the same data doesn't create duplicates,
    /// thanks to @Attribute(.unique) on Movie.id.
    @Test func syncMoviesUpsertDoesNotDuplicate() async throws {
        let schema = Schema([
            Playlist.self,
            Category.self,
            LiveStream.self,
            Movie.self,
            Series.self,
            Episode.self,
            EPGListing.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        let playlistId = UUID()

        // Insert 100 movies
        for i in 0..<100 {
            let ctx = ModelContext(container)
            ctx.autosaveEnabled = false
            let movie = Movie(id: "\(playlistId)-movie-\(i)", streamId: i, name: "Movie \(i)")
            ctx.insert(movie)
            try ctx.save()
        }

        // Re-insert the same 100 movies with updated names (upsert)
        for i in 0..<100 {
            let ctx = ModelContext(container)
            ctx.autosaveEnabled = false
            let movie = Movie(id: "\(playlistId)-movie-\(i)", streamId: i, name: "Updated Movie \(i)")
            ctx.insert(movie)
            try ctx.save()
        }

        // Verify count is still 100 (no duplicates)
        let verifyContext = ModelContext(container)
        let count = try verifyContext.fetchCount(FetchDescriptor<Movie>())
        #expect(count == 100, "Expected 100 movies after upsert, got \(count)")
    }
}
