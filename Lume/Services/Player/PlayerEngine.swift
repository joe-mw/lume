//
//  PlayerEngine.swift
//  Lume
//
//  Protocol defining the player engine interface
//

import Foundation
import AVFoundation

// MARK: - PlayerEngine Protocol

/// Protocol that all player engines must conform to
@MainActor
protocol PlayerEngine: AnyObject {
    /// Current playback time in seconds
    var currentTime: TimeInterval { get }

    /// Total duration of the media in seconds
    var duration: TimeInterval { get }

    /// Whether the player is currently playing
    var isPlaying: Bool { get }

    /// Playback rate (1.0 = normal speed)
    var rate: Float { get set }

    /// Current player state
    var state: PlayerState { get }

    /// Delegate for player events
    var delegate: PlayerEngineDelegate? { get set }

    /// Load a media URL for playback
    func load(url: URL)

    /// Start or resume playback
    func play()

    /// Pause playback
    func pause()

    /// Stop playback and release resources
    func stop()

    /// Seek to a specific time
    func seek(to time: TimeInterval)

    /// Set subtitle track
    func setSubtitleTrack(_ track: SubtitleTrack?)

    /// Set audio track
    func setAudioTrack(_ track: AudioTrack?)

    /// Set aspect ratio
    func setAspectRatio(_ ratio: AspectRatio)

    /// Get available subtitle tracks
    func getSubtitleTracks() -> [SubtitleTrack]

    /// Get available audio tracks
    func getAudioTracks() -> [AudioTrack]
}

// MARK: - Player State

enum PlayerState: Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case buffering
    case error(Error)
    case stopped

    static func == (lhs: PlayerState, rhs: PlayerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.ready, .ready),
             (.playing, .playing), (.paused, .paused), (.buffering, .buffering),
             (.stopped, .stopped):
            return true
        case (.error, .error):
            // Errors are considered equal if they're both errors
            return true
        default:
            return false
        }
    }
}

// MARK: - Player Engine Delegate

@MainActor
protocol PlayerEngineDelegate: AnyObject {
    func playerEngine(_ engine: PlayerEngine, didChangeState state: PlayerState)
    func playerEngine(_ engine: PlayerEngine, didUpdateTime time: TimeInterval)
    func playerEngine(_ engine: PlayerEngine, didUpdateDuration duration: TimeInterval)
    func playerEngine(_ engine: PlayerEngine, didEncounterError error: Error)
    func playerEngineDidFinishPlayback(_ engine: PlayerEngine)
}

// MARK: - Supporting Types

struct SubtitleTrack: Identifiable, Equatable {
    let id: String
    let language: String
    let label: String
    let isForced: Bool
}

struct AudioTrack: Identifiable, Equatable {
    let id: String
    let language: String
    let label: String
    let channelCount: Int
}

enum AspectRatio: String, CaseIterable {
    case fit = "Fit"
    case fill = "Fill"
    case stretch = "Stretch"
    case ratio16x9 = "16:9"
    case ratio4x3 = "4:3"

    var displayName: String {
        rawValue
    }
}

// MARK: - Player Error

enum PlayerError: LocalizedError {
    case loadFailed(Error)
    case playbackFailed(Error)
    case invalidURL
    case unsupportedFormat
    case networkError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load media: \(error.localizedDescription)"
        case .playbackFailed(let error):
            return "Playback failed: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid media URL"
        case .unsupportedFormat:
            return "Unsupported media format"
        case .networkError:
            return "Network error during playback"
        case .decodingError:
            return "Failed to decode media"
        }
    }
}
