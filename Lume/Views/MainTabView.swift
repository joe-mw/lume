//
//  MainTabView.swift
//  Lume
//
//  Main tab-based navigation for the app
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]

    @State private var selectedTab: TabItem = .movies
    @State private var navigationPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .movies) {
                MoviesView()
            } label: {
                Label("Movies", systemImage: "film")
            }

            Tab(value: .series) {
                SeriesView()
            } label: {
                Label("Series", systemImage: "tv")
            }

            Tab(value: .liveTV) {
                LiveTVView()
            } label: {
                Label("Live TV", systemImage: "antenna.radiowaves.left.and.right")
            }

            Tab(value: .settings) {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gear")
            }
        }
    }

    enum TabItem {
        case movies
        case series
        case liveTV
        case settings
    }
}

// Movies View is now in its own file

// Series View is now in its own file

// Live TV View is now in its own file

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]
    @State private var showingAddPlaylist = false

    var body: some View {
        NavigationStack {
            List {
                Section("Playlists") {
                    ForEach(playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(playlist.name)
                                    .font(.headline)
                                Text(playlist.serverURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deletePlaylists)

                    Button {
                        showingAddPlaylist = true
                    } label: {
                        Label("Add Playlist", systemImage: "plus")
                    }
                }

                Section("General") {
                    NavigationLink("Player Settings") {
                        Text("Player Settings")
                    }
                    NavigationLink("Appearance") {
                        Text("Appearance")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddPlaylist) {
                LoginView()
            }
        }
    }

    private func deletePlaylists(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(playlists[index])
            }
        }
    }
}

struct PlaylistDetailView: View {
    let playlist: Playlist

    var body: some View {
        List {
            Section("Server Information") {
                LabeledContent("Name", value: playlist.name)
                LabeledContent("Server URL", value: playlist.serverURL)
                LabeledContent("Username", value: playlist.username)
            }

            if let status = playlist.userStatus {
                Section("Account Status") {
                    LabeledContent("Status", value: status)
                    if let expDate = playlist.expDate {
                        LabeledContent("Expires", value: expDate)
                    }
                    if let maxConn = playlist.maxConnections {
                        LabeledContent("Max Connections", value: maxConn)
                    }
                    if let activeConn = playlist.activeConnections {
                        LabeledContent("Active Connections", value: activeConn)
                    }
                }
            }

            Section("Sync") {
                Toggle("Sync Enabled", isOn: .constant(playlist.syncEnabled))
                if let lastSync = playlist.lastSyncDate {
                    LabeledContent("Last Synced") {
                        Text(lastSync, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Sync Now") {
                    // TODO: Trigger sync
                }
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: Playlist.self, inMemory: true)
}
