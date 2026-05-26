//
//  MovieDetailView.swift
//  Lume
//
//  Detailed view for a movie with metadata and actions
//

import SwiftUI
import SwiftData

struct MovieDetailView: View {
    let movie: Movie

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var playlists: [Playlist]

    @State private var playingMedia: PlayableMedia?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with poster
                HStack(alignment: .top, spacing: 20) {
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
                                        .font(.system(size: 40))
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 150, height: 225)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)

                    VStack(alignment: .leading, spacing: 12) {
                        // Title
                        Text(movie.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        // Year and Duration
                        if let releaseDate = movie.releaseDate {
                            Text(releaseDate)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let duration = movie.durationSecs {
                            Text(formatDuration(duration))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // Rating
                        if movie.rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", movie.rating))
                                    .fontWeight(.semibold)
                                Text("/ 10")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }

                        // Genre
                        if let genre = movie.genre {
                            Text(genre)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding()

                // Play Button
                Button {
                    startPlayback()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(movie.watchProgress > 1 ? "Resume" : "Play")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
                .padding(.horizontal)
                .disabled(playlists.first == nil)

                // Action Buttons
                HStack(spacing: 16) {
                    ActionButton(
                        icon: movie.isFavorite ? "heart.fill" : "heart",
                        title: "Favorite",
                        isActive: movie.isFavorite,
                        action: { toggleFavorite() }
                    )

                    ActionButton(
                        icon: movie.isWatched ? "checkmark.circle.fill" : "checkmark.circle",
                        title: "Watched",
                        isActive: movie.isWatched,
                        action: { toggleWatched() }
                    )

                    ActionButton(
                        icon: "square.and.arrow.down",
                        title: "Download",
                        isActive: false,
                        action: { /* TODO */ }
                    )
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Description
                if let plot = movie.plot, !plot.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(plot)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Cast and Crew
                if let actors = movie.actors, !actors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cast")
                            .font(.headline)
                        Text(actors)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                if let director = movie.director, !director.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Director")
                            .font(.headline)
                        Text(director)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Trailer
                if let trailer = movie.youtubeTrailer, !trailer.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trailer")
                            .font(.headline)
                        Button {
                            // Open YouTube trailer
                            if let url = URL(string: "https://www.youtube.com/watch?v=\(trailer)") {
                                #if os(iOS)
                                UIApplication.shared.open(url)
                                #endif
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                Text("Watch Trailer")
                            }
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    movie.isFavorite.toggle()
                } label: {
                    Image(systemName: movie.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(movie.isFavorite ? .red : .primary)
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $playingMedia) { media in
            FullScreenPlayerView(media: media)
        }
        #else
        .sheet(item: $playingMedia) { media in
            FullScreenPlayerView(media: media)
        }
        #endif
    }

    private func startPlayback() {
        guard let playlist = playlists.first else { return }
        playingMedia = PlayableMedia.from(movie: movie, playlist: playlist)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func toggleFavorite() {
        movie.isFavorite.toggle()
    }

    private func toggleWatched() {
        movie.isWatched.toggle()
        if movie.isWatched {
            movie.watchProgress = Double(movie.durationSecs ?? 0)
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(isActive ? .blue : nil)
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(
            movie: Movie(
                id: "preview",
                streamId: 1,
                name: "Sample Movie"
            )
        )
    }
    .modelContainer(for: Playlist.self, inMemory: true)
}
