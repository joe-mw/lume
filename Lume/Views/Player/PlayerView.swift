//
//  PlayerView.swift
//  Lume
//
//  Video player view with controls
//

import SwiftUI
import SwiftData
import AVKit

struct PlayerView: View {
    let content: PlayableContent
    let playlist: Playlist

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var playerManager: PlayerManager
    @State private var showControls = true
    @State private var controlsTimer: Timer?

    init(content: PlayableContent, playlist: Playlist) {
        self.content = content
        self.playlist = playlist
        _playerManager = State(initialValue: PlayerManager())
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Video Player
            if let avPlayer = playerManager.getAVPlayer() {
                VideoPlayer(player: avPlayer) {
                    // No default controls
                }
                .ignoresSafeArea()
                .onTapGesture {
                    toggleControls()
                }
            } else {
                ProgressView("Loading...")
                    .tint(.white)
            }

            // Custom Controls Overlay
            if showControls {
                PlayerControlsView(
                    playerManager: playerManager,
                    content: content,
                    onDismiss: {
                        playerManager.stop()
                        dismiss()
                    }
                )
                .transition(.opacity)
            }
        }
        #if os(iOS)
        .statusBarHidden(!showControls)
        #endif
        .persistentSystemOverlays(showControls ? .visible : .hidden)
        .task {
            do {
                try await playerManager.play(content, from: playlist)
            } catch {
                print("Failed to play content: \(error)")
            }
        }
        .onDisappear {
            playerManager.stop()
        }
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }

        if showControls {
            resetControlsTimer()
        } else {
            controlsTimer?.invalidate()
        }
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            if playerManager.isPlaying {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls = false
                }
            }
        }
    }
}

// MARK: - Player Controls View

struct PlayerControlsView: View {
    @Bindable var playerManager: PlayerManager
    let content: PlayableContent
    let onDismiss: () -> Void

    @State private var isSeeking = false

    var body: some View {
        VStack {
            // Top Bar
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding()
                }

                Spacer()

                Text(contentTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Menu {
                    ForEach(playerManager.getSubtitleTracks()) { track in
                        Button {
                            playerManager.setSubtitleTrack(track)
                        } label: {
                            Text(track.label)
                        }
                    }
                } label: {
                    Image(systemName: "captions.bubble")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding()
                }
            }
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()

            // Center Controls
            HStack(spacing: 60) {
                Button {
                    playerManager.skipBackward(15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }

                Button {
                    if playerManager.isPlaying {
                        playerManager.pause()
                    } else {
                        playerManager.resume()
                    }
                } label: {
                    Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                }

                Button {
                    playerManager.skipForward(15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            // Bottom Bar
            VStack(spacing: 12) {
                // Progress Slider
                HStack(spacing: 12) {
                    Text(formatTime(playerManager.playbackProgress))
                        .font(.caption)
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Slider(
                        value: Binding(
                            get: { playerManager.playbackProgress },
                            set: { newValue in
                                if isSeeking {
                                    playerManager.seek(to: newValue)
                                }
                            }
                        ),
                        in: 0...max(playerManager.duration, 1)
                    ) { editing in
                        isSeeking = editing
                    }
                    .tint(.white)

                    Text(formatTime(playerManager.duration))
                        .font(.caption)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                .padding(.horizontal)

                // Additional Controls
                HStack {
                    // Volume (placeholder)
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(.white)

                    Spacer()

                    // Quality/Settings (placeholder)
                    Button {
                        // Settings
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.white)
                    }

                    // Picture in Picture (placeholder)
                    Button {
                        // PiP
                    } label: {
                        Image(systemName: "rectangle.on.rectangle")
                            .foregroundStyle(.white)
                    }

                    // Airplay
                    Button {
                        // Airplay
                    } label: {
                        Image(systemName: "airplayvideo")
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var contentTitle: String {
        switch content {
        case let movie as Movie:
            return movie.name
        case let episode as Episode:
            return "S\(episode.seasonNum)E\(episode.episodeNum): \(episode.title)"
        case let stream as LiveStream:
            return stream.name
        default:
            return "Now Playing"
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

#Preview {
    PlayerView(
        content: Movie(id: "preview", streamId: 1, name: "Sample Movie"),
        playlist: Playlist(name: "Test", serverURL: "", username: "", password: "")
    )
    .modelContainer(for: Playlist.self, inMemory: true)
}
