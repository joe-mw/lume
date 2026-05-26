import SwiftUI

#if canImport(KSPlayer)
import KSPlayer

/// KSPlayer-backed video host using `KSVideoPlayerView` for the full-screen
/// UI (controls, subtitle picker, scrubber, gestures). Progress reporting is
/// wired through a `KSVideoPlayer.Coordinator` we own.
///
/// To enable, add the package: File → Add Package Dependencies →
/// `https://github.com/kingslay/KSPlayer` (branch `main`).
@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
struct KSPlayerEngineView: View {
    let media: PlayableMedia
    @Binding var currentTime: TimeInterval
    @Binding var duration: TimeInterval

    @StateObject private var coordinator = KSVideoPlayer.Coordinator()

    var body: some View {
        let options = makeOptions()
        return KSVideoPlayerView(
            coordinator: coordinator,
            url: media.url,
            options: options,
            title: media.title
        )
        .onAppear {
            coordinator.onPlay = { current, total in
                if current.isFinite { currentTime = current }
                if total.isFinite, total > 0 { duration = total }
            }
        }
        .onDisappear {
            coordinator.resetPlayer()
        }
    }

    private func makeOptions() -> KSOptions {
        // Prefer FFmpeg decoding for IPTV streams that AVFoundation chokes on.
        KSOptions.secondPlayerType = KSMEPlayer.self

        let options = KSOptions()
        options.isAutoPlay = true
        options.preferredForwardBufferDuration = media.isLive ? 4 : 8
        if !media.isLive, media.startTime > 1 {
            options.startPlayTime = media.startTime
        }
        return options
    }
}

#else

/// Fallback view used when the KSPlayer Swift Package isn't linked into the
/// target. Renders an informational state so the build keeps working until
/// the dependency is added.
struct KSPlayerEngineView: View {
    let media: PlayableMedia
    @Binding var currentTime: TimeInterval
    @Binding var duration: TimeInterval

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("KSPlayer not installed")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("Add the KSPlayer Swift Package, or switch to AVPlayer in Settings → Player.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#endif
