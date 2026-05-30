//
//  CategoryContentGrid.swift
//  Lume
//
//  Shared grid and preview-row components used by both Movies and Series
//  category views, minimising duplication between the two.
//

import SwiftUI
import SwiftData

// MARK: - Full Category Content Grid ("Show All")

struct CategoryContentGrid<Item: Identifiable & Hashable, Card: View>: View {
    let title: String
    let items: [Item]
    let animationNamespace: Namespace.ID?
    let emptyTitle: String
    let emptyIcon: String
    let emptyDescription: String
    @ViewBuilder let card: (Item) -> Card

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        ScrollView {
            if items.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptyIcon,
                    description: Text(emptyDescription)
                )
                .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            card(item)
                                .matchedTransitionSourceIfAvailable(id: item.id, in: animationNamespace)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(title)
    }
}

// MARK: - Category Preview Row

struct CategoryPreviewRow<Item: Identifiable & Hashable, Card: View>: View {
    let category: Category
    let items: [Item]
    let animationNamespace: Namespace.ID?
    let emptyMessage: String
    @ViewBuilder let card: (Item) -> Card

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                NavigationLink(value: category) {
                    Text("Show All")
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)

            if items.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                card(item)
                                    .matchedTransitionSourceIfAvailable(id: item.id, in: animationNamespace)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 220)
            }
        }
    }
}

// MARK: - Movie Category View

struct MovieCategoryView: View {
    let category: Category
    @Query private var movies: [Movie]
    var animationNamespace: Namespace.ID?

    init(category: Category, sort: ContentSortOption, animationNamespace: Namespace.ID? = nil) {
        self.category = category
        self.animationNamespace = animationNamespace
        let categoryId = category.id
        _movies = Query(
            filter: #Predicate<Movie> { $0.categoryId == categoryId },
            sort: sort.movieDescriptors
        )
    }

    var body: some View {
        CategoryContentGrid(
            title: category.name,
            items: movies,
            animationNamespace: animationNamespace,
            emptyTitle: "No Movies",
            emptyIcon: "film.stack",
            emptyDescription: "This category has no movies",
            card: { MovieCardView(movie: $0) }
        )
    }
}

// MARK: - Movie Category Preview

struct MovieCategoryPreview: View {
    let category: Category
    @Query private var movies: [Movie]
    var animationNamespace: Namespace.ID?

    init(category: Category, limit: Int, sort: ContentSortOption, animationNamespace: Namespace.ID? = nil) {
        self.category = category
        self.animationNamespace = animationNamespace
        let categoryId = category.id
        var descriptor = FetchDescriptor<Movie>(
            predicate: #Predicate<Movie> { $0.categoryId == categoryId },
            sortBy: sort.movieDescriptors
        )
        descriptor.fetchLimit = limit
        _movies = Query(descriptor)
    }

    var body: some View {
        CategoryPreviewRow(
            category: category,
            items: movies,
            animationNamespace: animationNamespace,
            emptyMessage: "No movies in this category",
            card: { MovieCardView(movie: $0) }
        )
    }
}

// MARK: - Series Category View

struct SeriesCategoryView: View {
    let category: Category
    @Query private var series: [Series]
    var animationNamespace: Namespace.ID?

    init(category: Category, sort: ContentSortOption, animationNamespace: Namespace.ID? = nil) {
        self.category = category
        self.animationNamespace = animationNamespace
        let categoryId = category.id
        _series = Query(
            filter: #Predicate<Series> { $0.categoryId == categoryId },
            sort: sort.seriesDescriptors
        )
    }

    var body: some View {
        CategoryContentGrid(
            title: category.name,
            items: series,
            animationNamespace: animationNamespace,
            emptyTitle: "No Series",
            emptyIcon: "tv.fill",
            emptyDescription: "This category has no series",
            card: { SeriesCardView(series: $0) }
        )
    }
}

// MARK: - Series Category Preview

struct SeriesCategoryPreview: View {
    let category: Category
    @Query private var series: [Series]
    var animationNamespace: Namespace.ID?

    init(category: Category, limit: Int, sort: ContentSortOption, animationNamespace: Namespace.ID? = nil) {
        self.category = category
        self.animationNamespace = animationNamespace
        let categoryId = category.id
        var descriptor = FetchDescriptor<Series>(
            predicate: #Predicate<Series> { $0.categoryId == categoryId },
            sortBy: sort.seriesDescriptors
        )
        descriptor.fetchLimit = limit
        _series = Query(descriptor)
    }

    var body: some View {
        CategoryPreviewRow(
            category: category,
            items: series,
            animationNamespace: animationNamespace,
            emptyMessage: "No series in this category",
            card: { SeriesCardView(series: $0) }
        )
    }
}

// MARK: - Previews

#Preview("Movie Category Grid") {
    let container = previewContainer()
    let categories = try! container.mainContext.fetch(FetchDescriptor<Category>())
    let category = categories.first { $0.typeRaw == "vod" } ?? categories[0]
    return NavigationStack {
        MovieCategoryView(category: category, sort: .playlist, animationNamespace: nil)
    }
    .modelContainer(container)
}

#Preview("Movie Category Empty") {
    let container = previewContainer()
    let emptyCategory = Category(apiId: "999", name: "Empty Category", parentId: 0, type: .vod, playlist: PreviewData.samplePlaylist)
    return NavigationStack {
        MovieCategoryView(category: emptyCategory, sort: .playlist, animationNamespace: nil)
    }
    .modelContainer(container)
}

#Preview("Series Category Grid") {
    let container = previewContainer()
    let categories = try! container.mainContext.fetch(FetchDescriptor<Category>())
    let category = categories.first { $0.typeRaw == "series" } ?? categories[0]
    return NavigationStack {
        SeriesCategoryView(category: category, sort: .playlist, animationNamespace: nil)
    }
    .modelContainer(container)
}

#Preview("Series Category Empty") {
    let container = previewContainer()
    let emptyCategory = Category(apiId: "998", name: "Empty Series", parentId: 0, type: .series, playlist: PreviewData.samplePlaylist)
    return NavigationStack {
        SeriesCategoryView(category: emptyCategory, sort: .playlist, animationNamespace: nil)
    }
    .modelContainer(container)
}
