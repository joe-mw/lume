import SwiftUI

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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}