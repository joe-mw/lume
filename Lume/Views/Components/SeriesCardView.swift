//
//  SeriesCardView.swift
//  Lume
//
//  Card view for displaying a series cover and title
//

import SwiftUI

struct SeriesCardView: View {
    let series: Series

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover
            AsyncImage(url: URL(string: series.cover ?? "")) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "tv")
                                .foregroundStyle(.secondary)
                                .font(.largeTitle)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 120, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 2)

            // Title
            Text(series.name)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
    }
}

#Preview("Basic") {
    SeriesCardView(
        series: Series(
            id: "preview-1",
            seriesId: 1,
            name: "Sample Series"
        )
    )
}

#Preview("With Cover") {
    SeriesCardView(
        series: Series(
            id: "preview-2",
            seriesId: 2,
            name: "Breaking Bad",
            cover: "https://image.tmdb.org/t/p/w185/ggFHVNu6YYI5L9T5f7jFpBZdXl.jpg",
            rating: "9.5"
        )
    )
}

#Preview("With TMDB") {
    let series = Series(
        id: "preview-3",
        seriesId: 3,
        name: "Stranger Things",
        cover: "https://image.tmdb.org/t/p/w185/49WJfeN0m4b6B1JYbMqG0Y6j6aM.jpg",
        rating: "8.7"
    )
    series.tmdbId = 66732
    series.contentRating = "TV-14"
    return SeriesCardView(series: series)
}
