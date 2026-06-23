//
//  GenreBrowse.swift
//  Lume
//
//  "Browse by Genre" on the Movies and Series tabs. Genre cuts across the
//  provider categories — a title's genre comes from TMDB/playlist metadata, not
//  the category it lives in — so these surfaces are driven by the title's
//  `genre` string rather than a `categoryId`, mirroring the cross-category
//  library collection rows.
//

import SwiftData
import SwiftUI

// MARK: - Genre derivation

/// Upper bound on the fetch that enumerates a playlist's genres. The genre
/// vocabulary is tiny (a couple dozen names) and saturates almost immediately,
/// so a bounded sample surfaces every genre in practice while keeping the
/// derivation cheap on libraries with tens of thousands of titles — the same
/// trade-off `LibraryCollectionRows` makes for "Recently Added".
private let genreSampleLimit = 5000

enum GenreDerivation {
    static func movieGenres(in context: ModelContext, playlistPrefix: String, restriction: ContentRestriction) -> [String] {
        var descriptor = FetchDescriptor<Movie>(predicate: #Predicate { $0.genre != nil })
        descriptor.fetchLimit = genreSampleLimit
        let movies = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.id.hasPrefix(playlistPrefix) }
            .excludingRestricted(restriction)
        return GenreParser.distinctByFrequency(movies.map(\.genre))
    }

    static func seriesGenres(in context: ModelContext, playlistPrefix: String, restriction: ContentRestriction) -> [String] {
        var descriptor = FetchDescriptor<Series>(predicate: #Predicate { $0.genre != nil })
        descriptor.fetchLimit = genreSampleLimit
        let series = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.id.hasPrefix(playlistPrefix) }
            .excludingRestricted(restriction)
        return GenreParser.distinctByFrequency(series.map(\.genre))
    }
}

// MARK: - Browse-by-genre section

/// A tile grid of the genres present in the active playlist, most-common first.
/// Each tile navigates to that genre's full grid.
///
/// The owning view derives the genres and renders this only when the list is
/// non-empty: a view that collapses to nothing never receives `.task`/`.onAppear`
/// (the same EmptyView lifecycle trap `CachedAsyncImage` hit), so the derivation
/// must live on an always-present host — the browse `ScrollView` — not here.
struct GenreGridSection: View {
    let genres: [String]
    let type: CategoryType

    private let columns = [GridItem(.adaptive(minimum: CategoryTileMetrics.minimum), spacing: CategoryTileMetrics.spacing)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Genre")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: CategoryTileMetrics.spacing) {
                ForEach(genres, id: \.self) { genre in
                    NavigationLink(value: GenreSelection(genre: genre, type: type)) {
                        CategoryTile(name: genre)
                    }
                    .posterCardButtonStyle()
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Genre detail grids

/// The full grid of movies in a genre, reachable from a genre tile. The fetch
/// narrows to candidate rows in SQLite with `localizedStandardContains`, then
/// re-filters to exact-token matches in memory so substrings can't sneak in.
struct MovieGenreView: View {
    let genre: String
    let playlistPrefix: String
    var animationNamespace: Namespace.ID?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.contentRestriction) private var restriction

    @AppStorage(SortStorageKey.movieContent) private var contentSortRaw: String = ContentSortOption.playlist.rawValue
    @State private var movies: [Movie] = []
    @State private var canLoadMore = true
    @State private var isLoadingPage = false
    /// SQLite cursor position, distinct from `movies.count`. The in-memory
    /// genre/prefix/restriction filter below drops rows the substring fetch
    /// returned, so the displayed count and the source offset diverge — the
    /// offset must track rows pulled from SQLite, not rows shown.
    @State private var fetchedCount = 0
    /// The sort the current pages were loaded for. Pushing a detail cancels and
    /// (on pop) re-runs `.task`; reloading page one there would discard the
    /// loaded pages and reset the scroll position. Reload only when this differs.
    @State private var loadedSort: String?

    /// A popular genre in a large IPTV playlist can span thousands of titles;
    /// fetch a page at a time and load the next as the grid nears the end,
    /// rather than hydrating the whole genre into memory at once — mirroring
    /// `MovieCategoryView`.
    private let pageSize = 100

    private var contentSort: ContentSortOption {
        ContentSortOption(rawValue: contentSortRaw) ?? .playlist
    }

    var body: some View {
        CategoryContentGrid(
            title: genre,
            items: movies,
            animationNamespace: animationNamespace,
            emptyTitle: "No Movies",
            emptyIcon: "film.stack",
            emptyDescription: "No movies in this genre",
            sortRaw: $contentSortRaw,
            onLoadMore: { loadNextPage() },
            card: { MovieCardView(movie: $0) }
        )
        .task(id: contentSortRaw) {
            guard loadedSort != contentSortRaw else { return }
            loadedSort = contentSortRaw
            movies = []
            fetchedCount = 0
            canLoadMore = true
            loadNextPage()
        }
    }

    private func loadNextPage() {
        guard canLoadMore, !isLoadingPage else { return }
        isLoadingPage = true
        defer { isLoadingPage = false }
        let token = genre
        let prefix = playlistPrefix
        // Keep pulling raw pages until a batch surfaces at least one displayable
        // title or the source is exhausted: the in-memory filter can drop an
        // entire SQLite page, and without new trailing items the grid would
        // never fire `onLoadMore` again, stalling pagination.
        var added = 0
        while canLoadMore, added == 0 {
            var descriptor = FetchDescriptor<Movie>(
                predicate: #Predicate { ($0.genre?.localizedStandardContains(token)) ?? false },
                sortBy: contentSort.movieDescriptors
            )
            descriptor.fetchOffset = fetchedCount
            descriptor.fetchLimit = pageSize
            let rawPage = (try? modelContext.fetch(descriptor)) ?? []
            fetchedCount += rawPage.count
            if rawPage.count < pageSize { canLoadMore = false }
            let filtered = rawPage
                .filter { $0.id.hasPrefix(prefix) && GenreParser.contains($0.genre, genre: token) }
                .excludingRestricted(restriction)
            movies.append(contentsOf: filtered)
            added += filtered.count
        }
    }
}

/// The full grid of series in a genre.
struct SeriesGenreView: View {
    let genre: String
    let playlistPrefix: String
    var animationNamespace: Namespace.ID?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.contentRestriction) private var restriction

    @AppStorage(SortStorageKey.seriesContent) private var contentSortRaw: String = ContentSortOption.playlist.rawValue
    @State private var series: [Series] = []
    @State private var canLoadMore = true
    @State private var isLoadingPage = false
    /// SQLite cursor position, distinct from `series.count` — see `MovieGenreView`.
    @State private var fetchedCount = 0
    /// Sort the current pages were loaded for; reload only on change — see
    /// `MovieGenreView`, which explains why reappearance must not reset.
    @State private var loadedSort: String?

    /// Page a genre at a time rather than hydrating it whole; see `MovieGenreView`.
    private let pageSize = 100

    private var contentSort: ContentSortOption {
        ContentSortOption(rawValue: contentSortRaw) ?? .playlist
    }

    var body: some View {
        CategoryContentGrid(
            title: genre,
            items: series,
            animationNamespace: animationNamespace,
            emptyTitle: "No Series",
            emptyIcon: "tv.fill",
            emptyDescription: "No series in this genre",
            sortRaw: $contentSortRaw,
            onLoadMore: { loadNextPage() },
            card: { SeriesCardView(series: $0) }
        )
        .task(id: contentSortRaw) {
            guard loadedSort != contentSortRaw else { return }
            loadedSort = contentSortRaw
            series = []
            fetchedCount = 0
            canLoadMore = true
            loadNextPage()
        }
    }

    private func loadNextPage() {
        guard canLoadMore, !isLoadingPage else { return }
        isLoadingPage = true
        defer { isLoadingPage = false }
        let token = genre
        let prefix = playlistPrefix
        // Keep pulling until a batch yields displayable titles or the source is
        // exhausted — the in-memory filter can empty a whole page; see
        // `MovieGenreView.loadNextPage`.
        var added = 0
        while canLoadMore, added == 0 {
            var descriptor = FetchDescriptor<Series>(
                predicate: #Predicate { ($0.genre?.localizedStandardContains(token)) ?? false },
                sortBy: contentSort.seriesDescriptors
            )
            descriptor.fetchOffset = fetchedCount
            descriptor.fetchLimit = pageSize
            let rawPage = (try? modelContext.fetch(descriptor)) ?? []
            fetchedCount += rawPage.count
            if rawPage.count < pageSize { canLoadMore = false }
            let filtered = rawPage
                .filter { $0.id.hasPrefix(prefix) && GenreParser.contains($0.genre, genre: token) }
                .excludingRestricted(restriction)
            series.append(contentsOf: filtered)
            added += filtered.count
        }
    }
}
