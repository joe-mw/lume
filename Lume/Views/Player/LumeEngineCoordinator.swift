import AVFoundation
import Combine
import Foundation
import LumeEngine
import SwiftUI

/// Holds the engine's active subtitle cue text, refreshed from the coordinator's
/// 10 Hz playback tick. Deliberately a separate `ObservableObject` from
/// `LumeEngineCoordinator`: were the cue text `@Published` on the coordinator,
/// every per-tick update would fire the coordinator's `objectWillChange` and
/// re-render every overlay that observes it — flickering an open audio/subtitle
/// `Menu` and cancelling in-flight taps. Only the subtitle-rendering leaf
/// observes this model, so a cue change invalidates that leaf alone. Mirrors why
/// KSPlayer keeps its `SubtitleModel` off the controls overlay's observed surface.
@MainActor
final class SubtitleCueModel: ObservableObject {
    @Published private(set) var text: String?

    /// Assigns only on an actual change, so an unchanged cue repeated across
    /// ticks doesn't invalidate the leaf ten times a second.
    func update(_ newText: String?) {
        if text != newText { text = newText }
    }
}

/// Playback surface for the LumeEngine (FFmpeg) backend.
///
/// Wraps a `PlayerSession` per stream — the engine has no rebuild-in-place, so
/// `configure`/`reload` always tear the old session down and build a fresh one
/// (which is exactly the semantics `FullScreenPlayerView` expects from
/// `.id(engineAttempt)` teardown). Mirrors the coordinator surface of
/// `AVPlayerCoordinator`/`VLCPlayerCoordinator` so overlays stay engine-agnostic.
@MainActor
final class LumeEngineCoordinator: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    /// Set once the first frames are rendering; drives the loading indicator
    /// and the startup-failure watchdog.
    @Published private(set) var hasStartedPlayback = false
    @Published private(set) var videoInfo: PlayerVideoInfo?
    @Published private(set) var audioTrackOptions: [PlayerTrackOption] = []
    @Published private(set) var textTrackOptions: [PlayerTrackOption] = []
    @Published private(set) var isPipActive = false
    /// Active subtitle cue text, on its own observable so the 10 Hz tick that
    /// refreshes it doesn't invalidate this coordinator. A `@Published` here
    /// would fire `objectWillChange` on every tick, re-rendering every overlay
    /// that observes the coordinator (iOS `LumeEngineControlsOverlay`, tvOS
    /// `TVPlayerControlsOverlay`) — which flickers an open audio/subtitle `Menu`
    /// and cancels in-flight taps. Only the subtitle-rendering leaf observes
    /// this model, so a cue change invalidates that leaf alone.
    let subtitleCues = SubtitleCueModel()

    var isPipSupported: Bool {
        pipBridge?.isSupported ?? false
    }

    var playbackRate: Float = 1.0 {
        didSet {
            let session = session
            let rate = playbackRate
            Task { await session?.setRate(rate) }
        }
    }

    /// 10 Hz playback tick: (current, duration) in media-relative seconds.
    var onTime: ((TimeInterval, TimeInterval) -> Void)?
    /// Initial-load failure (hard error or startup timeout before first frame).
    var onPlaybackFailure: (() -> Void)?
    /// Mid-stream stall after playback had started (the engine's watchdog);
    /// the view routes this through `PlaybackRetryController`.
    var onStalled: (() -> Void)?
    /// Playback reached a healthy playing state — the view resets its
    /// reconnect budget.
    var onRecovered: (() -> Void)?
    var startupTimeout: TimeInterval = 40

    /// The engine's video surface for the hosting representable.
    private(set) var displayLayer: LumeDisplayLayer?

    private var session: PlayerSession?
    private var pipBridge: PictureInPictureBridge?
    private var mediaInfo: MediaInfo?
    private var currentMedia: PlayableMedia?
    private var eventTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    private var reportedFailure = false
    private var selectedSubtitleID: String?

    // MARK: Lifecycle

    func configure(media: PlayableMedia) {
        tearDown()
        currentMedia = media
        reportedFailure = false

        var configuration = PlayerConfiguration()
        configuration.bufferTarget = media.isLive ? 1.0 : 2.0
        configuration.demuxer.ioTimeout = 15_000_000
        configuration.demuxer.openTimeout = startupTimeout

        let session = PlayerSession(configuration: configuration)
        self.session = session
        displayLayer = session.renderer.displayLayer
        session.renderer.audioTimePitchAlgorithm = .timeDomain

        eventTask = Task { [events = session.events] in
            for await event in events {
                self.handle(event: event)
            }
        }
        tickTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                await self.tick()
            }
        }
        startupTask = Task { [startupTimeout] in
            try? await Task.sleep(for: .seconds(startupTimeout))
            guard !Task.isCancelled, !self.hasStartedPlayback else { return }
            self.reportFailure()
        }

        Task {
            do {
                let info = try await session.open(url: media.url.absoluteString)
                self.mediaInfo = info
                self.publishTracks(info: info)
                self.publishVideoInfo(info: info)
                self.pipBridge = PictureInPictureBridge(session: session, mediaInfo: info)
                if media.startTime > 1, !media.isLive {
                    await session.seek(to: media.startTime)
                }
                await session.play()
            } catch {
                self.reportFailure()
            }
        }
    }

    /// Fresh session for the same stream (stall recovery), resuming from the
    /// current position for VOD.
    func reload() {
        guard var media = currentMedia else { return }
        if media.kind == .vod, let session {
            let resumeAt = sessionPositionSnapshot(session)
            media = media.resuming(at: resumeAt)
        }
        configure(media: media)
    }

    func tearDown() {
        eventTask?.cancel()
        tickTask?.cancel()
        startupTask?.cancel()
        eventTask = nil
        tickTask = nil
        startupTask = nil
        pipBridge = nil
        if let session {
            Task { await session.shutdown() }
        }
        session = nil
        mediaInfo = nil
        displayLayer = nil
        isPlaying = false
        isBuffering = false
        hasStartedPlayback = false
        subtitleCues.update(nil)
        isPipActive = false
    }

    // MARK: Transport

    func togglePlay() {
        let session = session
        let playing = isPlaying
        Task {
            if playing {
                await session?.pause()
            } else {
                await session?.play()
            }
        }
    }

    func skip(by seconds: Double) {
        let session = session
        Task {
            guard let session else { return }
            let position = await session.position
            await session.seek(to: max(0, position + seconds))
        }
    }

    func seek(to seconds: TimeInterval) {
        let session = session
        Task { await session?.seek(to: seconds) }
    }

    func togglePictureInPicture() {
        pipBridge?.toggle()
        isPipActive = pipBridge?.isActive ?? false
    }

    // MARK: Tracks

    func selectAudioTrack(id: String) {
        guard let index = Int32(id) else { return }
        let session = session
        Task { await session?.selectAudioTrack(index) }
        if let info = mediaInfo {
            publishTracks(info: info, selectedAudioID: id)
        }
    }

    func selectTextTrack(id: String?) {
        selectedSubtitleID = id
        let session = session
        let index = id.flatMap(Int32.init)
        Task { await session?.selectSubtitleTrack(index) }
        if id == nil { subtitleCues.update(nil) }
        if let info = mediaInfo {
            publishTracks(info: info)
        }
    }

    // MARK: Internals

    private func handle(event: PlayerEvent) {
        switch event {
        case let .stateChanged(state):
            isPlaying = state == .playing
            isBuffering = state == .buffering || state == .opening
            if state == .playing {
                hasStartedPlayback = true
                onRecovered?()
            }
            if state == .failed {
                if hasStartedPlayback {
                    onStalled?()
                } else {
                    reportFailure()
                }
            }
        case .stalled:
            onStalled?()
        case .opened, .didSeek, .decoderDowngraded, .error:
            break
        }
    }

    private func tick() async {
        guard let session else { return }
        let position = await session.position
        let duration = await session.duration ?? 0
        onTime?(position, duration)

        let now = session.renderer.currentTime
        if now != .min {
            let cues = session.subtitles.activeCues(at: now)
            let text = cues.map(\.text).joined(separator: "\n")
            subtitleCues.update(text.isEmpty ? nil : text)
        }
    }

    private func publishTracks(info: MediaInfo, selectedAudioID: String? = nil) {
        audioTrackOptions = info.audioTracks.enumerated().map { position, track in
            let id = String(track.index)
            let fallbackSelected = selectedAudioID == nil && position == 0
            return PlayerTrackOption(
                id: id,
                label: trackLabel(track, fallback: "Audio \(position + 1)"),
                isSelected: selectedAudioID.map { $0 == id } ?? fallbackSelected
            )
        }
        textTrackOptions = info.subtitleTracks.enumerated().map { position, track in
            let id = String(track.index)
            return PlayerTrackOption(
                id: id,
                label: trackLabel(track, fallback: "Subtitle \(position + 1)"),
                isSelected: selectedSubtitleID == id
            )
        }
    }

    private func publishVideoInfo(info: MediaInfo) {
        guard let track = info.videoTracks.first, let video = track.video else { return }
        videoInfo = PlayerVideoInfo(
            width: video.width,
            height: video.height,
            fps: video.fps,
            codec: track.codecName
        )
    }

    private func trackLabel(_ track: TrackInfo, fallback: String) -> String {
        if let title = track.title, !title.isEmpty { return title }
        if let language = track.language, !language.isEmpty {
            return Locale.current.localizedString(forLanguageCode: language) ?? language
        }
        return fallback
    }

    private func reportFailure() {
        guard !reportedFailure else { return }
        reportedFailure = true
        onPlaybackFailure?()
    }

    private func sessionPositionSnapshot(_ session: PlayerSession) -> TimeInterval {
        let now = session.renderer.currentTime
        guard let info = mediaInfo, now != .min else { return 0 }
        return max(0, MediaTime.seconds(now - info.startTime))
    }
}

#if os(tvOS)
    /// The shared Apple TV overlay drives LumeEngine through the same surface
    /// as every other engine. All requirements already exist with matching
    /// signatures, so the conformance is empty.
    extension LumeEngineCoordinator: TVPlaybackEngine {}
#endif
