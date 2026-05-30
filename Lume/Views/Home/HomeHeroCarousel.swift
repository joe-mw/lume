//
//  HomeHeroCarousel.swift
//  Lume
//
//  A Netflix / Apple TV-style hero carousel for the top of the home screen.
//  Features trending movies the user owns using wide TMDB backdrop artwork,
//  auto-advancing every few seconds while honouring manual swipes.
//
//  The artwork lives in a paging ScrollView (`scrollTargetBehavior(.paging)` +
//  `scrollPosition`) so it works on macOS too, where the page tab style is
//  unavailable. The title / overview / buttons are drawn as a FIXED overlay on
//  top of the carousel (not inside the scrolling content) and simply update to
//  the current page. Keeping the text out of the scroll axis avoids the
//  unbounded-width proposal a horizontal ScrollView hands its content, which
//  otherwise stops the copy from wrapping.
//

import SwiftUI

/// One featured movie in the hero carousel: the owned `Movie` plus the
/// TMDB-sourced wide artwork and copy that make it look cinematic.
struct HeroMovie: Identifiable, Hashable {
    let movie: Movie
    let backdropURL: URL?
    let overview: String

    var id: String { movie.id }

    /// Prefer the wide TMDB backdrop; fall back to the provider poster so a
    /// title without a backdrop still renders something.
    var imageURL: URL? {
        backdropURL ?? URL(string: movie.streamIcon ?? "")
    }
}

struct HomeHeroCarousel: View {
    let movies: [HeroMovie]
    let onPlay: (Movie) -> Void

    @State private var currentID: String?
    @State private var isInteracting = false

    private let autoAdvanceInterval: Duration = .seconds(6)
    /// Width below which the hero switches to the stacked, full-width layout.
    private let compactWidthThreshold: CGFloat = 600

    #if os(macOS)
    private let heroHeight: CGFloat = 800
    #else
    private let heroHeight: CGFloat = 800
    #endif

    private var currentHero: HeroMovie? {
        movies.first { $0.id == currentID } ?? movies.first
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let isCompact = width < compactWidthThreshold

            ZStack(alignment: .bottomLeading) {
                artwork
                // Darken the bottom so the title and buttons stay legible over
                // any artwork.
                LinearGradient(
                    colors: [.clear, .black.opacity(0.15), .black.opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                if let hero = currentHero {
                    // Fixed overlay in normal layout — text wraps to `width`.
                    HeroInfo(hero: hero, isCompact: isCompact, onPlay: onPlay)
                        .id(hero.id)
                        .transition(.opacity)
                }

                pageIndicator
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(width: width, height: heroHeight)
            .clipped()
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.35), value: currentID)
        }
        .frame(height: heroHeight)
        .onAppear {
            if currentID == nil { currentID = movies.first?.id }
        }
        .task(id: movies.count) {
            await autoAdvance()
        }
    }

    // MARK: - Scrolling artwork

    @ViewBuilder
    private var artwork: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(movies) { hero in
                        HeroBackdrop(url: hero.imageURL)
                            .frame(width: width, height: heroHeight)
                            .id(hero.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, newPhase, _ in
                isInteracting = newPhase != .idle
            }
        }
    }

    // MARK: - Page indicator

    @ViewBuilder
    private var pageIndicator: some View {
        if movies.count > 1 {
            HStack(spacing: 8) {
                ForEach(movies) { hero in
                    Circle()
                        .fill(hero.id == currentID ? Color.white : Color.white.opacity(0.4))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 14)
            .animation(.easeInOut, value: currentID)
        }
    }

    // MARK: - Auto-advance

    private func autoAdvance() async {
        guard movies.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: autoAdvanceInterval)
            if Task.isCancelled { return }
            // Don't yank the carousel out from under an active gesture.
            guard !isInteracting else { continue }
            advance()
        }
    }

    private func advance() {
        guard let currentID,
              let index = movies.firstIndex(where: { $0.id == currentID }) else {
            withAnimation(.easeInOut) { self.currentID = movies.first?.id }
            return
        }
        let next = movies[(index + 1) % movies.count].id
        withAnimation(.easeInOut(duration: 0.6)) { self.currentID = next }
    }
}

// MARK: - Preview

#Preview("Multiple Movies") {
    let movies = [
        HeroMovie(
            movie: Movie(id: "preview-hero-1", streamId: 1, name: "The Matrix"),
            backdropURL: URL(string: "https://image.tmdb.org/t/p/w1280/fNG7i7RqM1T0sP1vQmRIqRnW.jpg"),
            overview: "A computer hacker learns about the true nature of reality."
        ),
        HeroMovie(
            movie: Movie(id: "preview-hero-2", streamId: 2, name: "Inception"),
            backdropURL: nil,
            overview: "A thief who steals corporate secrets through dream-sharing technology."
        ),
    ]
    HomeHeroCarousel(movies: movies, onPlay: { _ in })
}

#Preview("Single Movie") {
    let movies = [
        HeroMovie(
            movie: Movie(id: "preview-hero-3", streamId: 3, name: "The Dark Knight"),
            backdropURL: nil,
            overview: "When the menace known as the Joker wreaks havoc on Gotham."
        )
    ]
    HomeHeroCarousel(movies: movies, onPlay: { _ in })
}

#Preview("Empty") {
    HomeHeroCarousel(movies: [], onPlay: { _ in })
}

// MARK: - Backdrop image

private struct HeroBackdrop: View {
    let url: URL?

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.25))
                        .overlay { ProgressView() }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.25))
                        .overlay {
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Title / overview / buttons

private struct HeroInfo: View {
    let hero: HeroMovie
    let isCompact: Bool
    let onPlay: (Movie) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(hero.movie.name)
                .font(isCompact ? .title2.weight(.bold) : .largeTitle.weight(.bold))
                .lineLimit(2)
                .shadow(radius: 6)

            if !hero.overview.isEmpty {
                Text(hero.overview)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(radius: 4)
            }

            actionButtons
                .controlSize(.large)
                .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, isCompact ? 16 : 24)
        .padding(.top, isCompact ? 16 : 24)
        // Extra bottom inset so the (taller) stacked buttons clear the page
        // indicator instead of colliding with it / clipping at the edge.
        .padding(.bottom, 40)
        // Cap the readable column on very wide windows; fill the width when
        // compact. Pin the block to the leading edge.
        .frame(maxWidth: isCompact ? .infinity : 640, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isCompact {
            // Stacked, full-width buttons so nothing overflows horizontally.
            VStack(spacing: 12) {
                playButton(fullWidth: true)
                detailsButton(fullWidth: true)
            }
        } else {
            HStack(spacing: 12) {
                playButton(fullWidth: false)
                detailsButton(fullWidth: false)
            }
        }
    }

    private func playButton(fullWidth: Bool) -> some View {
        Button {
            onPlay(hero.movie)
        } label: {
            Label("Play", systemImage: "play.fill")
                .fontWeight(.semibold)
                .foregroundStyle(.black)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
    }

    private func detailsButton(fullWidth: Bool) -> some View {
        NavigationLink(value: hero.movie) {
            Label("Details", systemImage: "info.circle")
                .fontWeight(.semibold)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }
}
