import Foundation
import SwiftData
import SwiftUI

enum PreviewData {

    // MARK: - Playlist

    static let samplePlaylistID = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"

    static var samplePlaylist: Playlist {
        let p = Playlist(name: "My IPTV", serverURL: "http://example.com:8080", username: "demo", password: "••••••••")
        p.id = UUID(uuidString: samplePlaylistID)!
        p.userStatus = "Active"
        p.expDate = "1893456000"
        p.maxConnections = "1"
        p.activeConnections = "0"
        p.lastSyncDate = Date().addingTimeInterval(-86400)
        p.serverVersion = "1.0.0"
        p.serverTimezone = "Europe/London"
        return p
    }

    static var sampleCategories: [Category] {
        let p = samplePlaylist
        return [
            Category(apiId: "10", name: "Action", parentId: 0, type: .vod, playlist: p),
            Category(apiId: "11", name: "Comedy", parentId: 0, type: .vod, playlist: p),
            Category(apiId: "20", name: "News", parentId: 0, type: .live, playlist: p),
            Category(apiId: "30", name: "Drama", parentId: 0, type: .series, playlist: p),
        ]
    }

    // MARK: - Movie

    static var sampleMovie: Movie {
        let p = samplePlaylist
        let category = sampleCategories[0]
        let m = Movie(
            id: "\(p.id.uuidString)-movie-1",
            streamId: 1,
            name: "The Matrix",
            streamIcon: nil,
            rating: 8.7,
            rating5Based: 4.4,
            added: "2024-01-15",
            containerExtension: "mp4",
            num: 1,
            isAdult: 0,
            categoryId: category.id
        )
        m.plot = "A computer hacker learns about the true nature of reality and his role in the war against its controllers."
        m.genre = "Action, Sci-Fi"
        m.releaseDate = "1999-03-31"
        m.durationSecs = 8160
        m.director = "Lana Wachowski, Lilly Wachowski"
        m.actors = "Keanu Reeves, Laurence Fishburne, Carrie-Anne Moss"
        m.youtubeTrailer = "d6j_wN1QO7s"
        return m
    }

    static var sampleMovieWithTMDB: Movie {
        let m = sampleMovie
        m.backdropPath = "/fNG7i7RqM1T0sP1vQmRIqRnW.jpg"
        m.tagline = "Welcome to the Real World."
        m.contentRating = "R"
        m.tmdbId = 603
        m.tmdb = "603"
        m.tmdbEnrichedAt = Date().addingTimeInterval(-3600)
        m.similarTMDBIds = [604, 605, 606, 607]
        m.castMembers = sampleCast
        m.isFavorite = true
        return m
    }

    static var sampleMovieWatched: Movie {
        let m = sampleMovieWithTMDB
        m.id = "\(samplePlaylistID)-movie-2"
        m.name = "Inception"
        m.streamId = 2
        m.rating = 8.8
        m.tagline = "Your mind is the scene of the crime."
        m.plot = "A thief who steals corporate secrets through dream-sharing technology is given the task of planting an idea."
        m.genre = "Action, Sci-Fi, Thriller"
        m.releaseDate = "2010-07-16"
        m.durationSecs = 8880
        m.director = "Christopher Nolan"
        m.actors = "Leonardo DiCaprio, Joseph Gordon-Levitt, Elliot Page"
        m.youtubeTrailer = "YoHD9XEInc0"
        m.isWatched = true
        m.watchProgress = 8880
        m.isFavorite = false
        return m
    }

    // MARK: - Series

    static var sampleSeries: Series {
        let p = samplePlaylist
        let category = sampleCategories[3]
        let s = Series(
            id: "\(p.id.uuidString)-series-1",
            seriesId: 1,
            name: "Breaking Bad",
            cover: nil,
            plot: "A high school chemistry teacher turned methamphetamine manufacturer partners with a former student.",
            cast: "Bryan Cranston, Aaron Paul, Anna Gunn",
            director: "Vince Gilligan",
            genre: "Crime, Drama, Thriller",
            releaseDate: "2008-01-20",
            rating: "9.5",
            rating5Based: "4.8",
            num: 1,
            categoryId: category.id
        )
        return s
    }

    static var sampleSeriesWithTMDB: Series {
        let s = sampleSeries
        s.backdropPath = "/abc123backdrop.jpg"
        s.tagline = "I am the one who knocks."
        s.contentRating = "TV-MA"
        s.tmdbId = 1396
        s.tmdb = "1396"
        s.tmdbEnrichedAt = Date().addingTimeInterval(-3600)
        s.similarTMDBIds = [1397, 1398, 1399]
        s.castMembers = sampleSeriesCast
        s.isFavorite = true
        s.episodes = sampleEpisodes
        return s
    }

    static var sampleSeriesWithoutEpisodes: Series {
        let s = sampleSeriesWithTMDB
        s.id = "\(samplePlaylistID)-series-2"
        s.name = "Stranger Things"
        s.seriesId = 2
        s.episodes = []
        s.isFavorite = false
        return s
    }

    // MARK: - Episodes

    static var sampleEpisodes: [Episode] {
        let s = sampleSeriesWithTMDB
        return [
            Episode(
                id: "\(s.id)-ep-1",
                episodeId: "1",
                title: "Pilot",
                containerExtension: "mp4",
                seasonNum: 1,
                episodeNum: 1,
                series: s
            ),
            Episode(
                id: "\(s.id)-ep-2",
                episodeId: "2",
                title: "Cat's in the Bag...",
                containerExtension: "mp4",
                seasonNum: 1,
                episodeNum: 2,
                series: s
            ),
            Episode(
                id: "\(s.id)-ep-3",
                episodeId: "3",
                title: "And the Bag's in the River",
                containerExtension: "mp4",
                seasonNum: 1,
                episodeNum: 3,
                series: s
            ),
            Episode(
                id: "\(s.id)-ep-4",
                episodeId: "4",
                title: "Cancer Man",
                containerExtension: "mp4",
                seasonNum: 1,
                episodeNum: 4,
                series: s
            ),
        ]
    }

    // MARK: - Live Stream

    static var sampleLiveStream: LiveStream {
        let p = samplePlaylist
        let category = sampleCategories[2]
        return LiveStream(
            id: "\(p.id.uuidString)-live-1",
            streamId: 100,
            name: "BBC One",
            streamIcon: nil,
            epgChannelId: "BBC1",
            tvArchive: 0,
            tvArchiveDuration: 0,
            num: 1,
            categoryId: category.id
        )
    }

    static var sampleLiveStreamWithArchive: LiveStream {
        let ls = sampleLiveStream
        ls.id = "\(samplePlaylistID)-live-2"
        ls.streamId = 101
        ls.name = "CNN International"
        ls.tvArchive = 1
        ls.tvArchiveDuration = 7
        ls.isFavorite = true
        return ls
    }

    // MARK: - Hero Movies

    static var sampleHeroMovies: [HeroMovie] {
        let m1 = sampleMovieWithTMDB
        let m2 = sampleMovieWatched
        return [
            HeroMovie(movie: m1, backdropURL: URL(string: "https://image.tmdb.org/t/p/w1280/fNG7i7RqM1T0sP1vQmRIqRnW.jpg"), overview: m1.plot ?? ""),
            HeroMovie(movie: m2, backdropURL: nil, overview: m2.plot ?? ""),
        ]
    }

    // MARK: - Cast

    static var sampleCast: [CastMember] {
        let m = sampleMovie
        return [
            CastMember(id: "\(m.id)-cast-0", tmdbPersonId: 6384, name: "Keanu Reeves", role: "Neo", profilePath: nil, order: 0, movie: m),
            CastMember(id: "\(m.id)-cast-1", tmdbPersonId: 6193, name: "Laurence Fishburne", role: "Morpheus", profilePath: nil, order: 1, movie: m),
            CastMember(id: "\(m.id)-cast-2", tmdbPersonId: 530, name: "Carrie-Anne Moss", role: "Trinity", profilePath: nil, order: 2, movie: m),
            CastMember(id: "\(m.id)-cast-3", tmdbPersonId: 192, name: "Hugo Weaving", role: "Agent Smith", profilePath: nil, order: 3, movie: m),
        ]
    }

    static var sampleSeriesCast: [CastMember] {
        let s = sampleSeries
        return [
            CastMember(id: "\(s.id)-cast-0", tmdbPersonId: 17419, name: "Bryan Cranston", role: "Walter White", profilePath: nil, order: 0, series: s),
            CastMember(id: "\(s.id)-cast-1", tmdbPersonId: 234989, name: "Aaron Paul", role: "Jesse Pinkman", profilePath: nil, order: 1, series: s),
            CastMember(id: "\(s.id)-cast-2", tmdbPersonId: 1215295, name: "Anna Gunn", role: "Skyler White", profilePath: nil, order: 2, series: s),
        ]
    }

    // MARK: - Similar Items

    static var sampleSimilarItems: [HomeMediaItem] {
        [
            .movie(sampleMovieWatched),
            .movie(sampleMovie),
        ]
    }
}

// MARK: - Preview Container

func previewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Playlist.self, Movie.self, Series.self, LiveStream.self,
            Category.self, Episode.self, CastMember.self,
        configurations: config
    )

    let playlist = PreviewData.samplePlaylist
    container.mainContext.insert(playlist)

    for category in PreviewData.sampleCategories {
        container.mainContext.insert(category)
    }

    let movie = PreviewData.sampleMovie
    container.mainContext.insert(movie)

    let movieTMDB = PreviewData.sampleMovieWithTMDB
    for cast in movieTMDB.castMembers {
        container.mainContext.insert(cast)
    }
    container.mainContext.insert(movieTMDB)

    let movieWatched = PreviewData.sampleMovieWatched
    container.mainContext.insert(movieWatched)

    let series = PreviewData.sampleSeries
    container.mainContext.insert(series)

    let seriesTMDB = PreviewData.sampleSeriesWithTMDB
    for cast in seriesTMDB.castMembers {
        container.mainContext.insert(cast)
    }
    for ep in seriesTMDB.episodes {
        container.mainContext.insert(ep)
    }
    container.mainContext.insert(seriesTMDB)

    let seriesNoEp = PreviewData.sampleSeriesWithoutEpisodes
    container.mainContext.insert(seriesNoEp)

    let live = PreviewData.sampleLiveStream
    container.mainContext.insert(live)

    let liveArchive = PreviewData.sampleLiveStreamWithArchive
    container.mainContext.insert(liveArchive)

    try! container.mainContext.save()
    return container
}
