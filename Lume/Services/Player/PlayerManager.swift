//
//  PlayerManager.swift
//  Lume
//
//  Orchestrates player engines and manages playback lifecycle
//

import Foundation
import AVFoundation
import Observation

// MARK: - Player Manager

@MainActor
@Observable
final class PlayerManager: PlayerEngineDelegate {
    // MARK: - Properties

    private var currentEngine: PlayerEngine?
    private let preferredEngineType: PlayerType
    private let fallbackEngineType: PlayerType
    private let xtreamClient: XtreamClient

    // Observable state
    var currentContent: PlayableContent?
    var currentPlaylist: Playlist?
    var playbackProgress: TimeInterval = 0
    var duration: TimeInterval = 0
    var isPlaying: Bool = false
    var playerState: PlayerState = .idle
    var errorMessage: String?

    // Progress tracking
    private var progressTimer: Timer?
    private var lastProgressSaveTime: Date = Date()
    private let progressSaveInterval: TimeInterval = 5.0 // Save every 5 seconds

    // MARK: - Initialization

    init(
        preferredEngine: PlayerType = .avPlayer, // Using AVPlayer as default until KSPlayer is integrated
        fallbackEngine: PlayerType = .avPlayer,
        xtreamClient: XtreamClient = XtreamClient()
    ) {
        self.preferredEngineType = preferredEngine
        self.fallbackEngineType = fallbackEngine
        self.xtreamClient = xtreamClient
    }

    // MARK: - Playback Control

    /// Play content from a playlist
    func play(_ content: PlayableContent, from playlist: Playlist) async throws {
        // Build stream URL based on content type
        guard let url = buildStreamURL(for: content, playlist: playlist) else {
            throw PlayerError.invalidURL
        }

        currentContent = content
        currentPlaylist = playlist

        // Try preferred engine first
        do {
            let engine = createEngine(type: preferredEngineType)
            engine.delegate = self
            engine.load(url: url)
            engine.play()
            currentEngine = engine
            startProgressTracking()
        } catch {
            // Fallback to alternative engine
            print("Preferred engine failed, falling back to \(fallbackEngineType)")
            let fallbackEngine = createEngine(type: fallbackEngineType)
            fallbackEngine.delegate = self
            fallbackEngine.load(url: url)
            fallbackEngine.play()
            currentEngine = fallbackEngine
            startProgressTracking()
        }
    }

    /// Resume playback
    func resume() {
        currentEngine?.play()
    }

    /// Pause playback
    func pause() {
        currentEngine?.pause()
        saveProgress()
    }

    /// Stop playback and clean up
    func stop() {
        stopProgressTracking()
        saveProgress()
        currentEngine?.stop()
        currentEngine = nil
        currentContent = nil
        currentPlaylist = nil
        playbackProgress = 0
        duration = 0
    }

    /// Seek to a specific time
    func seek(to time: TimeInterval) {
        currentEngine?.seek(to: time)
        playbackProgress = time
    }

    /// Skip forward by a duration
    func skipForward(_ duration: TimeInterval = 15) {
        let newTime = min(playbackProgress + duration, self.duration)
        seek(to: newTime)
    }

    /// Skip backward by a duration
    func skipBackward(_ duration: TimeInterval = 15) {
        let newTime = max(playbackProgress - duration, 0)
        seek(to: newTime)
    }

    // MARK: - Player Settings

    func setSubtitleTrack(_ track: SubtitleTrack?) {
        currentEngine?.setSubtitleTrack(track)
    }

    func setAudioTrack(_ track: AudioTrack?) {
        currentEngine?.setAudioTrack(track)
    }

    func setAspectRatio(_ ratio: AspectRatio) {
        currentEngine?.setAspectRatio(ratio)
    }

    func setPlaybackRate(_ rate: Float) {
        currentEngine?.rate = rate
    }

    // MARK: - Track Information

    func getSubtitleTracks() -> [SubtitleTrack] {
        currentEngine?.getSubtitleTracks() ?? []
    }

    func getAudioTracks() -> [AudioTrack] {
        currentEngine?.getAudioTracks() ?? []
    }

    // MARK: - PlayerEngineDelegate

    func playerEngine(_ engine: PlayerEngine, didChangeState state: PlayerState) {
        playerState = state
        isPlaying = state == .playing

        if case .error(let error) = state {
            errorMessage = error.localizedDescription
        }
    }

    func playerEngine(_ engine: PlayerEngine, didUpdateTime time: TimeInterval) {
        playbackProgress = time

        // Save progress periodically
        if Date().timeIntervalSince(lastProgressSaveTime) >= progressSaveInterval {
            saveProgress()
            lastProgressSaveTime = Date()
        }
    }

    func playerEngine(_ engine: PlayerEngine, didUpdateDuration duration: TimeInterval) {
        self.duration = duration
    }

    func playerEngine(_ engine: PlayerEngine, didEncounterError error: Error) {
        errorMessage = error.localizedDescription
    }

    func playerEngineDidFinishPlayback(_ engine: PlayerEngine) {
        markContentAsWatched()
        saveProgress()
        stopProgressTracking()
    }

    // MARK: - Helper Methods

    private func createEngine(type: PlayerType) -> PlayerEngine {
        switch type {
        case .ksPlayer:
            return KSPlayerEngine()
        case .avPlayer:
            return AVPlayerEngine()
        }
    }

    private func buildStreamURL(for content: PlayableContent, playlist: Playlist) -> URL? {
        switch content {
        case let movie as Movie:
            return xtreamClient.buildMovieURL(for: movie, playlist: playlist)
        case let episode as Episode:
            return xtreamClient.buildEpisodeURL(for: episode, playlist: playlist)
        case let stream as LiveStream:
            return xtreamClient.buildLiveStreamURL(for: stream, playlist: playlist)
        default:
            return nil
        }
    }

    private func startProgressTracking() {
        stopProgressTracking()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Timer fires to keep UI updated
        }
    }

    private func stopProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func saveProgress() {
        guard let content = currentContent else { return }

        Task {
            // Update progress based on content type
            switch content {
            case let movie as Movie:
                movie.watchProgress = playbackProgress
                movie.lastWatchedDate = Date()

            case let episode as Episode:
                episode.watchProgress = playbackProgress
                episode.lastWatchedDate = Date()

            default:
                break
            }
        }
    }

    private func markContentAsWatched() {
        guard let content = currentContent else { return }

        Task {
            switch content {
            case let movie as Movie:
                movie.isWatched = true
                movie.watchProgress = duration

            case let episode as Episode:
                episode.isWatched = true
                episode.watchProgress = duration

            default:
                break
            }
        }
    }

    // MARK: - AVPlayer Access (for view integration)

    func getAVPlayer() -> AVPlayer? {
        (currentEngine as? AVPlayerEngine)?.getAVPlayer()
    }
}

// MARK: - Supporting Types

enum PlayerType {
    case ksPlayer
    case avPlayer
}

protocol PlayableContent: AnyObject {
    // Marker protocol for playable content (Movie, Episode, LiveStream)
}

// Extend existing models to conform to PlayableContent
extension Movie: PlayableContent {}
extension Episode: PlayableContent {}
extension LiveStream: PlayableContent {}
