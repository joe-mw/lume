import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]

    var body: some View {
        Group {
            if playlists.isEmpty {
                LoginView()
            } else {
                MainTabView()
            }
        }
        .task {
            if CommandLine.arguments.contains("-ui-testing") {
                seedTestPlaylist()
            }
        }
    }

    private func seedTestPlaylist() {
        guard playlists.isEmpty else { return }
        let playlist = Playlist(
            name: "Test Playlist",
            serverURL: "http://test.example.com:8080",
            username: "testuser",
            password: "testpass"
        )
        modelContext.insert(playlist)
        // Persist immediately so a separate ModelContext (e.g. the sync actor)
        // can see the seeded playlist without waiting for autosave.
        try? modelContext.save()
    }
}

#Preview("No Playlists") {
    ContentView()
}

#Preview("With Playlists") {
    ContentView()
        .modelContainer(for: Playlist.self, inMemory: true) { result in
            if case let .success(container) = result {
                let p = Playlist(name: "My IPTV", serverURL: "http://example.com:8080", username: "user", password: "pass")
                container.mainContext.insert(p)
            }
        }
}
