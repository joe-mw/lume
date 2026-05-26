import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]
    @State private var showingAddPlaylist = false

    var body: some View {
        NavigationStack {
            List {
                playlistsSection
                aboutSection
            }
            #if os(macOS)
            .listStyle(.inset(alternatesRowBackgrounds: true))
            #endif
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddPlaylist) {
                LoginView()
            }
        }
    }

    @ViewBuilder
    private var playlistsSection: some View {
        Section {
            if playlists.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("No Playlists")
                            .foregroundStyle(.secondary)
                        Button("Add Playlist") {
                            showingAddPlaylist = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .listRowInsets(EdgeInsets())
            } else {
                ForEach(playlists) { playlist in
                    NavigationLink {
                        PlaylistDetailView(playlist: playlist)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "tv")
                                .foregroundStyle(.secondary)
                                .font(.body)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(playlist.name)
                                Text(playlist.serverURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
                .onDelete(perform: deletePlaylists)

                Button {
                    showingAddPlaylist = true
                } label: {
                    Label("Add Playlist", systemImage: "plus")
                }
            }
        } header: {
            Text("Playlists")
        } footer: {
            if !playlists.isEmpty {
                Text("\(playlists.count) playlist\(playlists.count == 1 ? "" : "s")")
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "play.tv.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)
                    .background(.tint.opacity(0.1), in: .rect(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Lume")
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
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
