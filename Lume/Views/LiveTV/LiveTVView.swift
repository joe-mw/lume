//
//  LiveTVView.swift
//  Lume
//
//  Main view for browsing live TV channels
//

import SwiftUI
import SwiftData

struct LiveTVView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]
    @Query(filter: #Predicate<Category> { $0.typeRaw == "live" && $0.isHidden == false })
    private var categories: [Category]

    @State private var selectedPlaylist: Playlist?
    @State private var selectedCategory: Category?
    @State private var showingSync = false

    var body: some View {
        NavigationStack {
            Group {
                if playlists.isEmpty {
                    ContentUnavailableView(
                        "No Playlists",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Add a playlist in Settings to start watching live TV")
                    )
                } else if categories.isEmpty {
                    VStack(spacing: 20) {
                        ContentUnavailableView(
                            "No Channels",
                            systemImage: "antenna.radiowaves.left.and.right",
                            description: Text("Sync your playlist to load live TV channels")
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
                    HStack(spacing: 0) {
                        // Category sidebar
                        CategorySidebar(
                            categories: sortedCategories,
                            selectedCategory: $selectedCategory
                        )
                        .frame(width: 200)

                        Divider()

                        // Channels list
                        if let category = selectedCategory {
                            ChannelsList(category: category)
                        } else {
                            ContentUnavailableView(
                                "Select a Category",
                                systemImage: "list.bullet",
                                description: Text("Choose a category from the sidebar")
                            )
                        }
                    }
                }
            }
            .navigationTitle("Live TV")
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
                if selectedCategory == nil, let first = sortedCategories.first {
                    selectedCategory = first
                }
            }
            .sheet(isPresented: $showingSync) {
                if let playlist = selectedPlaylist ?? playlists.first {
                    SyncProgressView(playlist: playlist, isPresented: $showingSync)
                }
            }
            .navigationDestination(for: LiveStream.self) { stream in
                // TODO: Create LiveStreamDetailView
                Text("Live Stream: \(stream.name)")
            }
        }
    }

    private var sortedCategories: [Category] {
        categories.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }
}

// MARK: - Category Sidebar

struct CategorySidebar: View {
    let categories: [Category]
    @Binding var selectedCategory: Category?

    var body: some View {
        List(categories, selection: $selectedCategory) { category in
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)

                Text("\(category.liveStreams.count) channels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(category as Category?)
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Channels List

struct ChannelsList: View {
    let category: Category

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if category.liveStreams.isEmpty {
                    ContentUnavailableView(
                        "No Channels",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("This category has no channels")
                    )
                } else {
                    ForEach(sortedStreams) { stream in
                        NavigationLink(value: stream) {
                            LiveStreamCardView(stream: stream)
                                .padding(.horizontal)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading, 88)
                    }
                }
            }
        }
    }

    private var sortedStreams: [LiveStream] {
        category.liveStreams.sorted { stream1, stream2 in
            if let order1 = stream1.customOrder, let order2 = stream2.customOrder {
                return order1 < order2
            }
            return stream1.num < stream2.num
        }
    }
}

#Preview {
    LiveTVView()
        .modelContainer(for: Playlist.self, inMemory: true)
}
