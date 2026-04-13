import SwiftUI
import SwiftData

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