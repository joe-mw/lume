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

#Preview {
    MovieCardView(
        movie: Movie(
            id: "preview",
            streamId: 1,
            name: "Sample Movie",
            streamIcon: nil
        )
    )
}