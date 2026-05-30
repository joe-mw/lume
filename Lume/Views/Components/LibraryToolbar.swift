import SwiftUI

struct LibraryToolbarModifier: ViewModifier {
    let playlists: [Playlist]
    @Binding var selectedPlaylistID: String
    @Binding var categorySortRaw: String
    @Binding var contentSortRaw: String
    @Binding var showingSync: Bool
    @Binding var showingSettings: Bool
    let activePlaylist: Playlist?

    func body(content: Content) -> some View {
        content
            .toolbar {
                if playlists.count > 1 {
                    ToolbarItem(placement: .automatic) {
                        PlaylistSwitcher(playlists: playlists, selectedPlaylistID: $selectedPlaylistID)
                    }
                }

                ToolbarItem(placement: .automatic) {
                    SortMenu(categorySortRaw: $categorySortRaw, contentSortRaw: $contentSortRaw)
                }

                ToolbarItem(placement: .automatic) {
                    HStack {
                        Button {
                            showingSync = true
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }

                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingSync) {
                if let playlist = activePlaylist {
                    SyncProgressView(playlist: playlist, isPresented: $showingSync)
                }
            }
    }
}

extension View {
    func libraryToolbar(
        playlists: [Playlist],
        selectedPlaylistID: Binding<String>,
        categorySortRaw: Binding<String>,
        contentSortRaw: Binding<String>,
        showingSync: Binding<Bool>,
        showingSettings: Binding<Bool>,
        activePlaylist: Playlist?
    ) -> some View {
        modifier(LibraryToolbarModifier(
            playlists: playlists,
            selectedPlaylistID: selectedPlaylistID,
            categorySortRaw: categorySortRaw,
            contentSortRaw: contentSortRaw,
            showingSync: showingSync,
            showingSettings: showingSettings,
            activePlaylist: activePlaylist
        ))
    }
}
