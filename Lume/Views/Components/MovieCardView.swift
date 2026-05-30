//
//  MovieCardView.swift
//  Lume
//
//  Card view for displaying a movie poster and title
//

import SwiftUI

struct MovieCardView: View {
    let movie: Movie

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster
            AsyncImage(url: URL(string: movie.streamIcon ?? "")) { phase in
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
                            Image(systemName: "film")
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
            Text(movie.name)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
    }
}

#Preview("Basic") {
    MovieCardView(
        movie: Movie(
            id: "preview-1",
            streamId: 1,
            name: "Sample Movie",
            streamIcon: nil
        )
    )
}

#Preview("With Poster") {
    MovieCardView(
        movie: Movie(
            id: "preview-2",
            streamId: 2,
            name: "The Matrix",
            streamIcon: "https://image.tmdb.org/t/p/w185/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
            rating: 8.7,
            rating5Based: 4.4
        )
    )
}

#Preview("With TMDB") {
    let movie = Movie(
        id: "preview-3",
        streamId: 3,
        name: "Inception",
        streamIcon: "https://image.tmdb.org/t/p/w185/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg",
        rating: 8.8,
        rating5Based: 4.5
    )
    movie.tmdbId = 27205
    movie.contentRating = "PG-13"
    movie.plot = "A thief who steals corporate secrets through dream-sharing technology."
    return MovieCardView(movie: movie)
}