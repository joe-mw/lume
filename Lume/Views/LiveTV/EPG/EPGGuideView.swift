//
//  EPGGuideView.swift
//  Lume
//
//  A classic "TV guide" grid for a category: a frozen channel column on the
//  left, a frozen time ruler across the top, and programme blocks sized to
//  their duration. A live "now" line tracks the current moment.
//
//  Data (channels + listings) is queried and shaped into rows once, in this
//  parent. Scroll offset lives in the child scroller, so panning the grid never
//  re-runs the row-building work.
//

import SwiftData
import SwiftUI

struct EPGGuideView: View {
    let scope: LiveChannelScope
    let playlistPrefix: String
    let onPlay: (LiveStream) -> Void
    let onPlayCatchup: (LiveStream, EPGProgramCell) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var streams: [LiveStream]

    private let timeline: EPGTimeline

    /// The guide window's listings, grouped by channel and resolved in one
    /// off-main fetch scoped to *this category's* channels (see `EPGGuideLoader`).
    /// A view-context `@Query<EPGListing>` here instead pulled the entire guide
    /// window across every playlist onto the main thread and re-fired on every
    /// sync write — the freeze-on-open and stutter-while-scrolling this fixes.
    @State private var listingsByChannel: [String: [EPGWindowListing]] = [:]
    /// Observed so the guide refreshes once a guide import settles.
    @State private var epgSync = EPGSyncService.shared

    init(
        scope: LiveChannelScope,
        playlistPrefix: String,
        sort: ContentSortOption,
        onPlay: @escaping (LiveStream) -> Void,
        onPlayCatchup: @escaping (LiveStream, EPGProgramCell) -> Void = { _, _ in }
    ) {
        self.scope = scope
        self.playlistPrefix = playlistPrefix
        self.onPlay = onPlay
        self.onPlayCatchup = onPlayCatchup

        // A longer reach into the past than the default: aired programmes on
        // archive channels are replayable from here, so the window doubles as a
        // catch-up browser.
        let timeline = EPGTimeline.live(
            now: Date(), pointsPerMinute: EPGMetrics.current.pointsPerMinute, hoursBehind: 12
        )
        self.timeline = timeline

        _streams = Query(LiveChannelQuery.descriptor(for: scope, sort: sort))
    }

    private var scopedStreams: [LiveStream] {
        LiveChannelQuery.scoped(streams, scope: scope, playlistPrefix: playlistPrefix)
    }

    var body: some View {
        let channels = scopedStreams
        Group {
            if channels.isEmpty {
                ContentUnavailableView(
                    "No Channels",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("This category has no channels")
                )
            } else {
                EPGGridScroller(rows: buildRows(for: channels), timeline: timeline, onPlay: onPlay, onPlayCatchup: onPlayCatchup)
            }
        }
        // Reload when the channel set changes or a guide import settles. Keyed on
        // `isSyncing` (which flips twice per sync) rather than observing the store,
        // so the grid rebuilds a handful of times — not on every batch write.
        .task(id: "\(channels.count)-\(epgSync.isSyncing)") {
            await loadListings(for: channels)
        }
    }

    /// Tiles each scoped stream into a row from the pre-fetched window snapshots.
    /// Runs only when the streams or loaded listings change — not on scroll.
    private func buildRows(for channels: [LiveStream]) -> [EPGChannelRow] {
        EPGGridBuilder.rows(streams: channels, listingsByChannel: listingsByChannel, timeline: timeline)
    }

    private func loadListings(for channels: [LiveStream]) async {
        let channelIds = Array(Set(channels.compactMap(\.epgChannelId).filter { !$0.isEmpty }))
        guard !channelIds.isEmpty else {
            listingsByChannel = [:]
            return
        }
        let container = modelContext.container
        let windowStart = timeline.start
        let windowEnd = timeline.end
        listingsByChannel = await Task.detached(priority: .userInitiated) {
            EPGGuideLoader.load(
                container: container,
                channelIds: channelIds,
                windowStart: windowStart,
                windowEnd: windowEnd
            )
        }.value
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("EPG Guide") {
        EPGGuidePreviewHarness()
    }

    /// Seeds an in-memory store with channels and listings around "now" so the
    /// grid can be exercised in the canvas without a live playlist.
    private struct EPGGuidePreviewHarness: View {
        private let container: ModelContainer
        private let category: Category

        init() {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            let container = try! ModelContainer(
                for: Playlist.self, Category.self, LiveStream.self, EPGListing.self,
                configurations: config
            )
            let ctx = container.mainContext

            let playlist = Playlist(name: "Preview", serverURL: "http://example.com", username: "u", password: "p")
            ctx.insert(playlist)
            let category = Category(apiId: "20", name: "News", parentId: 0, type: .live, playlist: playlist)
            ctx.insert(category)

            let names = ["BBC One", "CNN International", "HBO", "Sky Sports", "Discovery", "Nat Geo", "ESPN", "ITV"]
            let titles = ["The Evening News", "Morning Show", "Wild Documentary", "Live Football", "Movie Night", "Talk of the Town"]
            let now = Date()
            let windowStart = now.addingTimeInterval(-3600)
            let windowEnd = now.addingTimeInterval(6 * 3600)

            for (index, name) in names.enumerated() {
                let channelId = "chan-\(index)"
                let stream = LiveStream(
                    id: "\(playlist.id.uuidString)-live-\(index)",
                    streamId: 100 + index,
                    name: name,
                    epgChannelId: channelId,
                    tvArchive: index % 3 == 0 ? 1 : 0,
                    tvArchiveDuration: 7,
                    num: index,
                    categoryId: category.id
                )
                ctx.insert(stream)

                var cursor = windowStart.addingTimeInterval(Double(index % 3) * 600) // stagger starts
                var slot = index
                while cursor < windowEnd {
                    let duration = TimeInterval([1800, 2700, 3600][slot % 3])
                    let end = cursor.addingTimeInterval(duration)
                    ctx.insert(EPGListing(
                        id: "\(channelId)-\(slot)",
                        channelId: channelId,
                        title: titles[slot % titles.count],
                        listingDescription: "A sample programme synopsis used for preview purposes only.",
                        start: cursor,
                        end: end
                    ))
                    cursor = end
                    slot += 1
                }
            }
            try? ctx.save()

            self.container = container
            self.category = category
        }

        var body: some View {
            EPGGuideView(scope: .category(category.id), playlistPrefix: "", sort: .playlist) { _ in }
                .modelContainer(container)
                .frame(minHeight: 520)
        }
    }
#endif
