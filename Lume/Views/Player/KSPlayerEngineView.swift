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
    @State private var hoverHideTask: Task<Void, Never>?

    var body: some View {
        let options = makeOptions()
        return KSVideoPlayerView(
            coordinator: coordinator,
            url: media.url,
            options: options,
            title: media.title
        )
        #if os(macOS)
        // KSPlayer's built-in `.onHover` only fires on the boundary, so the
        // controls auto-hide and never re-appear while the cursor moves inside
        // the video. We layer continuous hover on top to keep the mask shown
        // while there's any cursor movement over the player.
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active:
                coordinator.mask(show: true, autoHide: true)
                hoverHideTask?.cancel()
            case .ended:
                // Cursor left the player view entirely — hide controls shortly
                // after so we don't leave them stuck on screen.
                hoverHideTask?.cancel()
                hoverHideTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    guard !Task.isCancelled else { return }
                    coordinator.isMaskShow = false
                }
            }
        }
        #endif
        .onAppear {
            coordinator.onPlay = { current, total in
                if current.isFinite { currentTime = current }
                if total.isFinite, total > 0 { duration = total }
            }
        }
        .onDisappear {
            hoverHideTask?.cancel()
            coordinator.resetPlayer()
        }
    }

    private func makeOptions() -> KSOptions {
        // Prefer FFmpeg decoding for IPTV streams that AVFoundation chokes on.
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true

        let options = KSOptions()
        options.preferredForwardBufferDuration = media.isLive ? 4 : 8
        if !media.isLive, media.startTime > 1 {
            options.startPlayTime = media.startTime
        }
        #if os(macOS)
        // When true, KSPlayer rewrites the window's aspect ratio + frame on
        // `readyToPlay`. In fullscreen the frame call doesn't resize the
        // window itself, but the aspect-ratio constraint shifts the rendered
        // video to the bottom-left origin, leaving a thick black bar above
        // and below depending on aspect. Disable so the video fills the
        // window and is centered by the player layer's aspect-fit.
        options.automaticWindowResize = false
        #endif
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

#Preview("Fallback") {
    KSPlayerEngineView(
        media: PlayableMedia(
            id: "preview",
            url: URL(string: "https://example.com/stream.m3u8")!,
            title: "Sample Video",
            subtitle: nil,
            posterURL: nil,
            kind: .vod,
            startTime: 0,
            contentRef: .movie("preview")
        ),
        currentTime: .constant(0),
        duration: .constant(120)
    )
    .preferredColorScheme(.dark)
}
