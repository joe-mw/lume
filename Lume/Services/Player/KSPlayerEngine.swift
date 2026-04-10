//
//  KSPlayerEngine.swift
//  Lume
//
//  KSPlayer-based player engine implementation
//  TODO: Implement once KSPlayer dependency is properly integrated
//

import Foundation

// MARK: - KSPlayerEngine

@MainActor
final class KSPlayerEngine: PlayerEngine {
    weak var delegate: PlayerEngineDelegate?

    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isPlaying: Bool = false
    var rate: Float = 1.0
    var state: PlayerState = .idle

    init() {
        // TODO: Initialize KSPlayer
    }

    func load(url: URL) {
        // TODO: Implement KSPlayer loading
        state = .loading
    }

    func play() {
        // TODO: Implement KSPlayer play
        state = .playing
    }

    func pause() {
        // TODO: Implement KSPlayer pause
        state = .paused
    }

    func stop() {
        // TODO: Implement KSPlayer stop
        state = .stopped
    }

    func seek(to time: TimeInterval) {
        // TODO: Implement KSPlayer seek
    }

    func setSubtitleTrack(_ track: SubtitleTrack?) {
        // TODO: Implement KSPlayer subtitle track selection
    }

    func setAudioTrack(_ track: AudioTrack?) {
        // TODO: Implement KSPlayer audio track selection
    }

    func setAspectRatio(_ ratio: AspectRatio) {
        // TODO: Implement KSPlayer aspect ratio
    }

    func getSubtitleTracks() -> [SubtitleTrack] {
        // TODO: Implement KSPlayer subtitle tracks retrieval
        return []
    }

    func getAudioTracks() -> [AudioTrack] {
        // TODO: Implement KSPlayer audio tracks retrieval
        return []
    }
}
