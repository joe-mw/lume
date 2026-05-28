import SwiftUI
import SwiftData

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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Playlist.self, inMemory: true)
}
