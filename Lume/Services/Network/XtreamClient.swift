//
//  XtreamClient.swift
//  Lume
//
//  Xtream Codes API client
//

import Foundation

enum XtreamError: Error {
    case invalidURL
    case authenticationFailed
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case serverError(Int)
}

// MARK: - XtreamClient

class XtreamClient: APIClient {
    struct Configuration {
        let serverURL: String
        let username: String
        let password: String
        let timeout: TimeInterval

        init(serverURL: String, username: String, password: String, timeout: TimeInterval = 30) {
            self.serverURL = serverURL
            self.username = username
            self.password = password
            self.timeout = timeout
        }
    }

    let configuration: Configuration
    let session: URLSession

    init(configuration: Configuration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.session = urlSession
    }

    // Convenience initializer for backward compatibility
    convenience init(urlSession: URLSession = .shared) {
        let config = Configuration(
            serverURL: "",
            username: "",
            password: "",
            timeout: 30
        )
        self.init(configuration: config, urlSession: urlSession)
    }

    // MARK: - Helper Methods

    private func buildURL(serverURL: String, path: String, queryItems: [URLQueryItem]) -> URL? {
        var components = URLComponents(string: serverURL)
        // Ensure the path is appended properly
        if !(components?.path.hasSuffix("/") ?? false) && !path.hasPrefix("/") {
            components?.path.append("/")
        }
        components?.path.append(path)

        let existingItems = components?.queryItems ?? []
        components?.queryItems = existingItems + queryItems

        return components?.url
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw XtreamError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw XtreamError.authenticationFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw XtreamError.serverError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }

    // MARK: - API Methods

    /// 1. Get Server and User Info
    func getInfo(playlist: Playlist) async throws -> XtreamAuthResponse {
        let queryItems = [
            URLQueryItem(name: "username", value: playlist.username),
            URLQueryItem(name: "password", value: playlist.password)
        ]

        guard let url = buildURL(serverURL: playlist.serverURL, path: "player_api.php", queryItems: queryItems) else {
            throw XtreamError.invalidURL
        }

        return try await request(url)
    }

    /// 2. Get Live Categories
    func getLiveCategories(playlist: Playlist) async throws -> [XtreamCategory] {
        let queryItems = [
            URLQueryItem(name: "username", value: playlist.username),
            URLQueryItem(name: "password", value: playlist.password),
            URLQueryItem(name: "action", value: "get_live_categories")
        ]

        guard let url = buildURL(serverURL: playlist.serverURL, path: "player_api.php", queryItems: queryItems) else {
            throw XtreamError.invalidURL
        }

        return try await request(url)
    }

    /// 3. Get Live Streams
    func getLiveStreams(playlist: Playlist, categoryId: String? = nil) async throws -> [XtreamLiveStream] {
        var queryItems = [
            URLQueryItem(name: "username", value: playlist.username),
            URLQueryItem(name: "password", value: playlist.password),
            URLQueryItem(name: "action", value: "get_live_streams")
        ]
        if let categoryId = categoryId {
            queryItems.append(URLQueryItem(name: "category_id", value: categoryId))
        }

        guard let url = buildURL(serverURL: playlist.serverURL, path: "player_api.php", queryItems: queryItems) else {
            throw XtreamError.invalidURL
        }

        return try await request(url)
    }

    /// 4. Get VOD Categories
    func getVODCategories(playlist: Playlist) async throws -> [XtreamCategory] {
        let queryItems = [
            URLQueryItem(name: "username", value: playlist.username),
            URLQueryItem(name: "password", value: playlist.password),
            URLQueryItem(name: "action", value: "get_vod_categories")
        ]

        guard let url = buildURL(serverURL: playlist.serverURL, path: "player_api.php", queryItems: queryItems) else {
            throw XtreamError.invalidURL
        }

        return try await request(url)
    }

    /// 5. Get VOD Streams
    func getVODStreams(playlist: Playlist, categoryId: String? = nil) async throws -> [XtreamVODStream] {
        var queryItems = [
            URLQueryItem(name: "username", value: playlist.username),
            URLQueryItem(name: "password", value: playlist.password),
            URLQueryItem(name: "action", value: "get_vod_streams")
        ]
        if let categoryId = categoryId {
            queryItems.append(URLQueryItem(name: "category_id", value: categoryId))
        }

        guard let url = buildURL(serverURL: playlist.serverURL, path: "player_api.php", queryItems: queryItems) else {
            throw XtreamError.invalidURL
        }

        return try await request(url)
    }

    /// 6. Get VOD Info
    func getVODInfo(playlist: Playlist, vodId: Int) async throws -> XtreamVODInfo {
        let queryItems = [
            URLQueryItem(name: "username", value: playlist.username),
            URLQueryItem(name: "password", value: playlist.password),
            URLQueryItem(name: "action", value: "get_vod_info"),
            URLQueryItem(name: "vod_id", value: String(vodId))
        ]

        guard let url = buildURL(serverURL: playlist.serverURL, path: "player_api.php", queryItems: queryItems) else {
            throw XtreamError.invalidURL
        }

        return try await request(url)
    }

    /// 7. Get Series Categories
    func getSeriesCategories(playlist: Playlist) async throws -> [XtreamCategory] {
        let queryItems = [
            URLQueryItem(name: "username", value: playlist.username),
            URLQueryItem(name: "password", value: playlist.password),
            URLQueryItem(name: "action", value: "get_series_categories")
        ]

        guard let url = buildURL(serverURL: playlist.serverURL, path: "player_api.php", queryItems: queryItems) else {
            throw XtreamError.invalidURL
        }

        return try await request(url)
    }

    /// 8. Get Series
    func getSeries(playlist: Playlist, categoryId: String? = nil) async throws -> [XtreamSeries] {
        var queryItems = [
            URLQueryItem(name: "username", value: playlist.username),
            URLQueryItem(name: "password", value: playlist.password),
            URLQueryItem(name: "action", value: "get_series")
        ]
        if let categoryId = categoryId {
            queryItems.append(URLQueryItem(name: "category_id", value: categoryId))
        }

        guard let url = buildURL(serverURL: playlist.serverURL, path: "player_api.php", queryItems: queryItems) else {
            throw XtreamError.invalidURL
        }

        return try await request(url)
    }

    /// 9. Get Series Info
    func getSeriesInfo(playlist: Playlist, seriesId: Int) async throws -> XtreamSeriesInfoResponse {
        let queryItems = [
            URLQueryItem(name: "username", value: playlist.username),
            URLQueryItem(name: "password", value: playlist.password),
            URLQueryItem(name: "action", value: "get_series_info"),
            URLQueryItem(name: "series_id", value: String(seriesId))
        ]

        guard let url = buildURL(serverURL: playlist.serverURL, path: "player_api.php", queryItems: queryItems) else {
            throw XtreamError.invalidURL
        }

        return try await request(url)
    }

    /// 10. Get Short EPG
    func getShortEPG(playlist: Playlist, streamId: Int, limit: Int? = nil) async throws -> [XtreamShortEPG] {
        var queryItems = [
            URLQueryItem(name: "username", value: playlist.username),
            URLQueryItem(name: "password", value: playlist.password),
            URLQueryItem(name: "action", value: "get_short_epg"),
            URLQueryItem(name: "stream_id", value: String(streamId))
        ]
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        guard let url = buildURL(serverURL: playlist.serverURL, path: "player_api.php", queryItems: queryItems) else {
            throw XtreamError.invalidURL
        }

        struct ShortEPGResponse: Decodable {
            let epg_listings: [XtreamShortEPG]
        }

        do {
            let response: ShortEPGResponse = try await request(url)
            return response.epg_listings
        } catch {
            // Try array fallback if not wrapped
            if let arrayResponse: [XtreamShortEPG] = try? await request(url) {
                return arrayResponse
            }
            throw error
        }
    }

    // MARK: - Stream URL Building

    /// Builds a playback URL for a movie
    func buildMovieURL(for movie: Movie, playlist: Playlist) -> URL? {
        let ext = movie.containerExtension ?? "mp4"
        return URL(string: "\(playlist.serverURL)/movie/\(playlist.username)/\(playlist.password)/\(movie.streamId).\(ext)")
    }

    /// Builds a playback URL for an episode
    func buildEpisodeURL(for episode: Episode, playlist: Playlist) -> URL? {
        let ext = episode.containerExtension
        return URL(string: "\(playlist.serverURL)/series/\(playlist.username)/\(playlist.password)/\(episode.episodeId).\(ext)")
    }

    /// Builds a playback URL for a live stream
    func buildLiveStreamURL(for stream: LiveStream, playlist: Playlist, format: StreamFormat = .m3u8) -> URL? {
        return URL(string: "\(playlist.serverURL)/live/\(playlist.username)/\(playlist.password)/\(stream.streamId).\(format.rawValue)")
    }

    /// Builds a catchup/timeshift URL for a live stream
    func buildCatchupURL(for stream: LiveStream, playlist: Playlist, startTime: Date, duration: TimeInterval = 3600) -> URL? {
        let timestamp = Int(startTime.timeIntervalSince1970)
        let durationInt = Int(duration)
        return URL(string: "\(playlist.serverURL)/timeshift/\(playlist.username)/\(playlist.password)/\(durationInt)/\(timestamp)/\(stream.streamId).m3u8")
    }
}

// MARK: - Supporting Types

enum StreamFormat: String {
    case m3u8
    case ts
}
