//
//  AVPlayerEngine.swift
//  Lume
//
//  AVPlayer-based player engine implementation
//

import Foundation
import AVFoundation
import Combine

// MARK: - AVPlayerEngine

@MainActor
final class AVPlayerEngine: PlayerEngine {
    // MARK: - Properties

    weak var delegate: PlayerEngineDelegate?

    private let player: AVPlayer
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    private(set) var state: PlayerState = .idle {
        didSet {
            if oldValue != state {
                delegate?.playerEngine(self, didChangeState: state)
            }
        }
    }

    var currentTime: TimeInterval {
        player.currentTime().seconds
    }

    var duration: TimeInterval {
        playerItem?.duration.seconds ?? 0
    }

    var isPlaying: Bool {
        player.rate > 0
    }

    var rate: Float {
        get { player.rate }
        set { player.rate = newValue }
    }

    // MARK: - Initialization

    init() {
        self.player = AVPlayer()
        setupPlayer()
    }

    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - Setup

    private func setupPlayer() {
        // Add periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.delegate?.playerEngine(self, didUpdateTime: time.seconds)
        }

        // Observe player status
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.state = .stopped
                self.delegate?.playerEngineDidFinishPlayback(self)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    self.state = .error(error)
                    self.delegate?.playerEngine(self, didEncounterError: error)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - PlayerEngine Protocol

    func load(url: URL) {
        state = .loading

        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        // Observe status
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .readyToPlay:
                    self.state = .ready
                    self.delegate?.playerEngine(self, didUpdateDuration: self.duration)
                case .failed:
                    if let error = playerItem.error {
                        self.state = .error(PlayerError.loadFailed(error))
                        self.delegate?.playerEngine(self, didEncounterError: error)
                    }
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)

        // Observe buffering
        playerItem.publisher(for: \.isPlaybackLikelyToKeepUp)
            .sink { [weak self] isLikelyToKeepUp in
                guard let self = self else { return }
                if !isLikelyToKeepUp && self.isPlaying {
                    self.state = .buffering
                } else if isLikelyToKeepUp && self.state == .buffering {
                    self.state = .playing
                }
            }
            .store(in: &cancellables)

        self.playerItem = playerItem
        player.replaceCurrentItem(with: playerItem)
    }

    func play() {
        guard state != .error(PlayerError.invalidURL) else { return }
        player.play()
        state = .playing
    }

    func pause() {
        player.pause()
        state = .paused
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        playerItem = nil
        state = .stopped
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime) { [weak self] completed in
            guard let self = self, completed else { return }
            self.delegate?.playerEngine(self, didUpdateTime: time)
        }
    }

    func setSubtitleTrack(_ track: SubtitleTrack?) {
        guard let playerItem = playerItem else { return }

        // Disable all subtitle tracks
        for group in playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) as? [AVMediaSelectionGroup] ?? [] {
            playerItem.select(nil, in: group)
        }

        // Enable selected track
        if let track = track,
           let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible),
           let option = group.options.first(where: { $0.displayName == track.label }) {
            playerItem.select(option, in: group)
        }
    }

    func setAudioTrack(_ track: AudioTrack?) {
        guard let playerItem = playerItem else { return }

        if let track = track,
           let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
           let option = group.options.first(where: { $0.displayName == track.label }) {
            playerItem.select(option, in: group)
        }
    }

    func setAspectRatio(_ ratio: AspectRatio) {
        // Note: AVPlayer doesn't directly support aspect ratio changes
        // This would need to be handled in the view layer
    }

    func getSubtitleTracks() -> [SubtitleTrack] {
        guard let playerItem = playerItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return []
        }

        return group.options.map { option in
            SubtitleTrack(
                id: option.displayName,
                language: option.locale?.languageCode ?? "unknown",
                label: option.displayName,
                isForced: option.hasMediaCharacteristic(.containsOnlyForcedSubtitles)
            )
        }
    }

    func getAudioTracks() -> [AudioTrack] {
        guard let playerItem = playerItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return []
        }

        return group.options.map { option in
            AudioTrack(
                id: option.displayName,
                language: option.locale?.languageCode ?? "unknown",
                label: option.displayName,
                channelCount: 2 // Default, would need proper detection
            )
        }
    }

    // MARK: - Helper Methods

    /// Get the underlying AVPlayer instance for view integration
    func getAVPlayer() -> AVPlayer {
        player
    }
}
