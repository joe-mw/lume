//
//  MoviesView.swift
//  Lume
//
//  Main view for browsing movies
//

import SwiftUI
import SwiftData

struct MoviesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]
    @Query(filter: #Predicate<Category> { $0.typeRaw == "vod" && $0.isHidden == false })
    private var categories: [Category]

    @State private var selectedPlaylist: Playlist?
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var showingSync = false

    var body: some View {
        NavigationStack {
            Group {
                if playlists.isEmpty {
                    ContentUnavailableView(
                        "No Playlists",
                        systemImage: "film.stack",
                        description: Text("Add a playlist in Settings to start browsing movies")
                    )
                } else if categories.isEmpty {
                    VStack(spacing: 20) {
                        ContentUnavailableView(
                            "No Movies",
                            systemImage: "film.stack",
                            description: Text("Sync your playlist to load movies")
                        )

                        if let playlist = playlists.first {
                            Button {
                                selectedPlaylist = playlist
                                showingSync = true
                            } label: {
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24, pinnedViews: []) {
                            ForEach(sortedCategories) { category in
                                CategorySection(category: category)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Movies")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if let playlist = playlists.first {
                        Menu {
                            ForEach(playlists) { p in
                                Button {
                                    selectedPlaylist = p
                                } label: {
                                    Label(p.name, systemImage: selectedPlaylist?.id == p.id ? "checkmark" : "")
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedPlaylist?.name ?? playlist.name)
                                    .font(.headline)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                        }
                    }
                }

                ToolbarItem(placement: .automatic) {
                    HStack {
                        if isSyncing {
                            ProgressView()
                        }

                        Button {
                            showingSync = true
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }

                        Button {
                            // Search action
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }
            }
            .task {
                if selectedPlaylist == nil, let first = playlists.first {
                    selectedPlaylist = first
                }
            }
            .sheet(isPresented: $showingSync) {
                if let playlist = selectedPlaylist ?? playlists.first {
                    SyncProgressView(playlist: playlist, isPresented: $showingSync)
                }
            }
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie)
            }
        }
    }

    private var sortedCategories: [Category] {
        categories.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }
}

// MARK: - Category Section

struct CategorySection: View {
    let category: Category

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            Text(category.name)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            // Movies scroll view
            if category.movies.isEmpty {
                Text("No movies in this category")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(category.movies.sorted(by: { $0.num < $1.num })) { movie in
                            NavigationLink(value: movie) {
                                MovieCardView(movie: movie)
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

// MARK: - Sync Progress View

struct SyncProgressView: View {
    let playlist: Playlist
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var progress: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isSyncing {
                    ProgressView(value: progress) {
                        Text("Syncing...")
                            .font(.headline)
                    }
                    .progressViewStyle(.linear)
                    .padding()

                    Text("This may take a few minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let error = syncError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundStyle(.red)

                        Text("Sync Failed")
                            .font(.headline)

                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            syncError = nil
                            startSync()
                        } label: {
                            Text("Try Again")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)

                        Text("Ready to Sync")
                            .font(.headline)

                        Text("This will download all categories and content from your playlist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()

                        Button {
                            startSync()
                        } label: {
                            Text("Start Sync")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Sync Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(isSyncing)
                }
            }
        }
    }

    private func startSync() {
        isSyncing = true
        syncError = nil
        progress = 0

        Task {
            do {
                let syncManager = ContentSyncManager(modelContainer: modelContext.container)
                try await syncManager.syncPlaylist(playlist, full: true)

                await MainActor.run {
                    isSyncing = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    MoviesView()
        .modelContainer(for: Playlist.self, inMemory: true)
}
