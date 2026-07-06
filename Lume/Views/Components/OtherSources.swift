//
//  OtherSources.swift
//  Lume
//
//  Resolves other entries of the *same* title (matched by TMDB id) — within the
//  same playlist (e.g. an alternate quality or language stream) and, separately,
//  across the user's other playlists. Shared by the movie and series detail
//  screens (iOS, macOS and tvOS) so the "Other Sources" and "Available on Other
//  Playlists" rows behave identically everywhere.
//

import Foundation
import SwiftData

enum OtherSources {
    /// A same-title entry found on a *different* playlist, labelled with that
    /// playlist's name so the UI can badge it.
    struct PlaylistSource: Identifiable, Hashable {
        let item: HomeMediaItem
        let playlistName: String

        var id: String {
            item.id
        }
    }

    /// Other `Movie` entries that share `movie`'s TMDB id and playlist, excluding
    /// `movie` itself. Empty when the movie has no TMDB id.
    static func resolve(for movie: Movie, in context: ModelContext) -> [HomeMediaItem] {
        guard let tmdbId = movie.tmdbId else { return [] }
        let prefix = movie.id.components(separatedBy: "-movie-").first
        let matches = (try? context.fetch(
            FetchDescriptor<Movie>(predicate: #Predicate { $0.tmdbId == tmdbId })
        )) ?? []
        return matches
            .filter { samePlaylist($0.id, as: prefix) && $0.id != movie.id }
            .map { .movie($0) }
    }

    /// Other `Series` entries that share `series`'s TMDB id and playlist,
    /// excluding `series` itself. Empty when the series has no TMDB id.
    static func resolve(for series: Series, in context: ModelContext) -> [HomeMediaItem] {
        guard let tmdbId = series.tmdbId else { return [] }
        let prefix = series.id.components(separatedBy: "-series-").first
        let matches = (try? context.fetch(
            FetchDescriptor<Series>(predicate: #Predicate { $0.tmdbId == tmdbId })
        )) ?? []
        return matches
            .filter { samePlaylist($0.id, as: prefix) && $0.id != series.id }
            .map { .series($0) }
    }

    /// `Movie` entries sharing `movie`'s TMDB id on *other* playlists, labelled
    /// with the owning playlist's name. Empty when the movie has no TMDB id.
    static func resolveOtherPlaylists(for movie: Movie, in context: ModelContext) -> [PlaylistSource] {
        guard let tmdbId = movie.tmdbId else { return [] }
        let prefix = movie.id.components(separatedBy: "-movie-").first
        let matches = (try? context.fetch(
            FetchDescriptor<Movie>(predicate: #Predicate { $0.tmdbId == tmdbId })
        )) ?? []
        return crossPlaylistSources(
            matches.map { ($0.id, HomeMediaItem.movie($0)) },
            excludingPlaylist: prefix,
            in: context
        )
    }

    /// `Series` entries sharing `series`'s TMDB id on *other* playlists, labelled
    /// with the owning playlist's name. Empty when the series has no TMDB id.
    static func resolveOtherPlaylists(for series: Series, in context: ModelContext) -> [PlaylistSource] {
        guard let tmdbId = series.tmdbId else { return [] }
        let prefix = series.id.components(separatedBy: "-series-").first
        let matches = (try? context.fetch(
            FetchDescriptor<Series>(predicate: #Predicate { $0.tmdbId == tmdbId })
        )) ?? []
        return crossPlaylistSources(
            matches.map { ($0.id, HomeMediaItem.series($0)) },
            excludingPlaylist: prefix,
            in: context
        )
    }

    /// Whether `id` belongs to the same playlist as `prefix` (the `<uuid>` part of
    /// a content id). A nil prefix means the owner couldn't be determined — in
    /// that case keep the match rather than hiding everything.
    private static func samePlaylist(_ id: String, as prefix: String?) -> Bool {
        guard let prefix else { return true }
        return id.hasPrefix(prefix)
    }

    /// Keeps the candidates outside `prefix`'s playlist and labels each with its
    /// owning playlist's name. Candidates whose playlist can't be resolved are
    /// dropped — without a playlist there are no credentials to play them with.
    /// A nil prefix means the owner couldn't be determined; return nothing so the
    /// same matches aren't duplicated across both rows (`samePlaylist` keeps them
    /// all in the same-playlist row in that case).
    private static func crossPlaylistSources(
        _ candidates: [(id: String, item: HomeMediaItem)],
        excludingPlaylist prefix: String?,
        in context: ModelContext
    ) -> [PlaylistSource] {
        guard let prefix else { return [] }
        let others = candidates.filter { !$0.id.hasPrefix(prefix) }
        guard !others.isEmpty else { return [] }
        let playlists = (try? context.fetch(FetchDescriptor<Playlist>())) ?? []
        return others
            .compactMap { candidate in
                playlists.first { candidate.id.hasPrefix($0.id.uuidString) }
                    .map { PlaylistSource(item: candidate.item, playlistName: $0.name) }
            }
            .sorted { $0.playlistName.localizedStandardCompare($1.playlistName) == .orderedAscending }
    }
}
