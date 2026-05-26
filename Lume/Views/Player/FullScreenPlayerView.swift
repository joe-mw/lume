import SwiftUI
import SwiftData
import AVFoundation

/// Top-level full-screen video host. Picks the engine implementation based on
/// the user setting, owns progress state, and persists watch progress back
/// into SwiftData for VOD content.
struct FullScreenPlayerView: View {
    let media: PlayableMedia

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(PlayerSettings.engineKey) private var engineRaw: String = PlayerEngineKind.defaultValue.rawValue

    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var lastSaved: Date = .distantPast

    private var engine: PlayerEngineKind {
        PlayerEngineKind(rawValue: engineRaw) ?? .defaultValue
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            playerView
                .ignoresSafeArea()

            closeButton
                .padding(.top, 4)
                .padding(.leading, 4)
        }
        #if os(iOS)
        .statusBarHidden(true)
        #endif
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onChange(of: currentTime) { _, _ in
            persistProgress(force: false)
        }
        .task {
            configureAudioSessionForPlayback()
        }
        .onDisappear {
            persistProgress(force: true)
            releaseAudioSession()
        }
    }

    @ViewBuilder
    private var playerView: some View {
        switch engine {
        case .avPlayer:
            AVPlayerEngineView(media: media, currentTime: $currentTime, duration: $duration)
        case .ksPlayer:
            KSPlayerEngineView(media: media, currentTime: $currentTime, duration: $duration)
        }
    }

    private var closeButton: some View {
        Button {
            persistProgress(force: true)
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
        }
        .padding(12)
        .accessibilityLabel("Close player")
    }

    private func configureAudioSessionForPlayback() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [])
        try? session.setActive(true, options: [])
        #endif
    }

    private func releaseAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func persistProgress(force: Bool) {
        guard !media.isLive else {
            if force { touchLiveLastWatched() }
            return
        }
        guard currentTime > 0 else { return }
        if !force, Date().timeIntervalSince(lastSaved) < 5 { return }
        lastSaved = Date()

        let now = currentTime
        let total = duration
        let completed = total > 0 && now / total >= 0.9

        switch media.contentRef {
        case .movie(let id):
            updateMovie(id: id, progress: now, completed: completed)
        case .episode(let id):
            updateEpisode(id: id, progress: now, completed: completed)
        case .live:
            break
        }
    }

    private func updateMovie(id: String, progress: TimeInterval, completed: Bool) {
        var descriptor = FetchDescriptor<Movie>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let movie = try? modelContext.fetch(descriptor).first else { return }
        movie.watchProgress = progress
        movie.lastWatchedDate = Date()
        if completed { movie.isWatched = true }
        try? modelContext.save()
    }

    private func updateEpisode(id: String, progress: TimeInterval, completed: Bool) {
        var descriptor = FetchDescriptor<Episode>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let episode = try? modelContext.fetch(descriptor).first else { return }
        episode.watchProgress = progress
        episode.lastWatchedDate = Date()
        if completed { episode.isWatched = true }
        try? modelContext.save()
    }

    private func touchLiveLastWatched() {
        guard case .live(let id) = media.contentRef else { return }
        var descriptor = FetchDescriptor<LiveStream>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let stream = try? modelContext.fetch(descriptor).first else { return }
        stream.lastWatchedDate = Date()
        try? modelContext.save()
    }
}
