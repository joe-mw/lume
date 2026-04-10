import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]

    var body: some View {
        if playlists.isEmpty {
            LoginView()
        } else {
            MainTabView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Playlist.self, inMemory: true)
}
