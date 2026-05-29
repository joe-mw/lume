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

    @State private var selectedTab: TabItem = .home
    @State private var navigationPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .home) {
                HomeView()
            } label: {
                Label("Home", systemImage: "house")
            }

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
        case home
        case movies
        case series
        case liveTV
        case settings
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: Playlist.self, inMemory: true)
}
