//
//  EPGGridScroller.swift
//  Lume
//
//  The guide grid's scrollable machinery: the frozen ruler/channel panes, the
//  single 2D-scrollable programme surface, and the shared scroll sync that
//  keeps them aligned. `EPGGuideView` shapes the data; this file renders and
//  navigates it. On tvOS the channel column doubles as the focus hub — see
//  `EPGFrozenColumn`.
//

import SwiftUI

// MARK: - Scroller

/// Lays out the frozen panes (corner, ruler, channel column) beside the single
/// scrollable grid. The same layout serves every platform: touch and pointer
/// drag the grid, tvOS moves it by focus, and the frozen column sits *beside*
/// the grid so a focused programme is never hidden behind it.
struct EPGGridScroller: View {
    let rows: [EPGChannelRow]
    let timeline: EPGTimeline
    /// Bumped by `EPGGuideView` when the underlying cells change; the grid
    /// subtree is `Equatable`-gated on it.
    let dataVersion: Int
    let onPlay: (LiveStream) -> Void
    let onPlayCatchup: (LiveStream, EPGProgramCell) -> Void

    private let metrics = EPGMetrics.current
    private let now = Date()

    @State private var sync = EPGScrollSync()
    @State private var selection: EPGSelection?
    @State private var jumpToken = 0
    /// Which row's programme currently holds focus, reported by every cell
    /// button (used by the tvOS Menu escape and entry bounce).
    @FocusState private var focusedGridRowID: String?

    var body: some View {
        content
            .sheet(item: $selection) { selection in
                EPGProgramDetailView(
                    stream: selection.stream,
                    cell: selection.cell,
                    now: now,
                    onPlay: { onPlay(selection.stream) },
                    onPlayCatchup: { onPlayCatchup(selection.stream, selection.cell) }
                )
            }
    }

    /// Activates a tapped programme: a past one still inside the channel's
    /// archive plays as catch-up; everything else plays the channel live.
    private func activate(row: EPGChannelRow, cell: EPGProgramCell) {
        if !cell.isGap, cell.isPast(at: now),
           PlayableMedia.isCatchupAvailable(stream: row.stream, start: cell.start, now: now)
        {
            onPlayCatchup(row.stream, cell)
        } else {
            onPlay(row.stream)
        }
    }

    #if os(tvOS)
        /// The tvOS grid is UIKit: UICollectionView's native recycling and
        /// focus handling replace the SwiftUI scroller, whose per-press focus
        /// bookkeeping and per-frame graph updates dominated device traces on
        /// large categories no matter how little of the guide's own code ran.
        private var content: some View {
            EPGCollectionGrid(
                rows: rows,
                timeline: timeline,
                now: now,
                dataVersion: dataVersion,
                nowTarget: nowScrollTarget,
                onActivate: { row, cell in activate(row: row, cell: cell) },
                onPlayChannel: { onPlay($0.stream) },
                onShowDetails: { row, cell in
                    selection = EPGSelection(id: cell.id, stream: row.stream, cell: cell)
                }
            )
        }
    #else
        private var content: some View {
            VStack(spacing: 0) {
                // Header: corner (with the jump-to-now button) + time ruler.
                HStack(spacing: 0) {
                    corner
                        .frame(width: metrics.channelColumnWidth, height: metrics.headerHeight)

                    EPGRulerStrip(timeline: timeline, metrics: metrics, now: now, sync: sync)
                }
                .frame(height: metrics.headerHeight)

                Divider()

                // Body: frozen channel column + scrollable programme grid.
                HStack(spacing: 0) {
                    EPGFrozenColumn(rows: rows, metrics: metrics, sync: sync)

                    EPGGrid(
                        rows: rows,
                        timeline: timeline,
                        metrics: metrics,
                        now: now,
                        sync: sync,
                        dataVersion: dataVersion,
                        jumpToken: jumpToken,
                        nowTarget: nowScrollTarget,
                        focusedRowIndex: nil,
                        focusedGridRowID: $focusedGridRowID,
                        suppressFocusFlash: false,
                        onExit: { _ in },
                        onPlay: { row, cell in activate(row: row, cell: cell) },
                        onShowDetails: { row, cell in
                            selection = EPGSelection(id: cell.id, stream: row.stream, cell: cell)
                        }
                    )
                    .equatable()
                }
            }
            .background(.background)
        }
    #endif

    /// Scroll offset that places "now" just inside the leading edge of the grid.
    private var nowScrollTarget: CGFloat {
        max(0, timeline.x(for: now) - 12)
    }

    #if !os(tvOS)
        private var corner: some View {
            Button {
                jumpToken += 1
            } label: {
                Label("Now", systemImage: "smallcircle.filled.circle")
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .trailing) { Rectangle().fill(.quaternary).frame(width: 1) }
        }
    #endif
}

// MARK: - Grid

/// The single scrollable surface. Owns its scroll position (used only for
/// programmatic jump-to-now) and publishes its offset to the shared sync. Its
/// programme rows live in a separate child so the per-frame scroll-position
/// write-back never rebuilds them.
///
/// `Equatable` (wrapped in `.equatable()` by the scroller): the scroller's
/// body re-runs on every remote press (its focus states live there), and
/// without the gate each press would re-evaluate this whole subtree. The
/// comparison covers everything the subtree renders or reacts to.
private struct EPGGrid: View, Equatable {
    let rows: [EPGChannelRow]
    let timeline: EPGTimeline
    let metrics: EPGMetrics
    let now: Date
    let sync: EPGScrollSync
    let dataVersion: Int
    let jumpToken: Int
    let nowTarget: CGFloat
    /// The channel-column row holding focus (tvOS). The grid scrolls to keep it
    /// visible, since the frozen column mirrors the grid and can't scroll itself.
    let focusedRowIndex: Int?
    /// The scroller-owned focus binding every cell button reports into.
    var focusedGridRowID: FocusState<String?>.Binding
    /// Render cells unfocused while the guide's entry grace is active (tvOS).
    let suppressFocusFlash: Bool
    /// Menu pressed while focus is inside the grid (tvOS); carries the id of
    /// the row whose programme held focus, so the escape can land on the same
    /// channel in the column.
    let onExit: (String?) -> Void
    let onPlay: (EPGChannelRow, EPGProgramCell) -> Void
    let onShowDetails: (EPGChannelRow, EPGProgramCell) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.dataVersion == rhs.dataVersion
            && lhs.rows.count == rhs.rows.count
            && lhs.jumpToken == rhs.jumpToken
            && lhs.focusedRowIndex == rhs.focusedRowIndex
            && lhs.suppressFocusFlash == rhs.suppressFocusFlash
            && lhs.nowTarget == rhs.nowTarget
            && lhs.timeline == rhs.timeline
    }

    @State private var position = ScrollPosition()
    @State private var didInitialScroll = false
    /// A combined horizontal+vertical ScrollView centers content that is shorter
    /// than the viewport. The frozen channel column pins its cells to the top, so
    /// without this the two panes drift apart when a category has only a few
    /// channels. Pinning the rows to at least the viewport height (top-aligned)
    /// keeps them level on every platform.
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            EPGRows(
                rows: rows,
                timeline: timeline,
                metrics: metrics,
                now: now,
                sync: sync,
                dataVersion: dataVersion,
                focusedGridRowID: focusedGridRowID,
                suppressFocusFlash: suppressFocusFlash,
                onPlay: onPlay,
                onShowDetails: onShowDetails
            )
            .equatable()
            .frame(minHeight: viewportHeight, alignment: .topLeading)
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewportHeight = geo.size.height }
                    .onChange(of: geo.size.height) { viewportHeight = $1 }
            }
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGRect.self) { CGRect(origin: $0.contentOffset, size: $0.containerSize) } action: { _, new in
            sync.offset = CGPoint(x: max(0, new.origin.x), y: max(0, new.origin.y))
            let window = EPGRealizeWindow.around(
                offset: max(0, new.origin.x),
                viewport: new.width,
                blockLength: 30 * metrics.pointsPerMinute
            )
            if sync.window != window {
                sync.window = window
            }
            let rowWindow = EPGRealizeWindow.around(
                offset: max(0, new.origin.y),
                viewport: new.height,
                blockLength: 2 * (metrics.rowHeight + metrics.rowSpacing)
            )
            if sync.rowWindow != rowWindow {
                sync.rowWindow = rowWindow
            }
        }
        #if os(tvOS)
        .focusSection()
        .onExitCommand { onExit(focusedGridRowID.wrappedValue) }
        #endif
        .onAppear {
            guard !didInitialScroll else { return }
            didInitialScroll = true
            // Seed the realization windows around the initial scroll target so
            // the first build already realizes the right cells; the viewports
            // over-estimate a hair and the first geometry event corrects them.
            sync.window = EPGRealizeWindow.around(
                offset: nowTarget,
                viewport: 2400,
                blockLength: 30 * metrics.pointsPerMinute
            )
            sync.rowWindow = EPGRealizeWindow.around(
                offset: 0,
                viewport: 1400,
                blockLength: 2 * (metrics.rowHeight + metrics.rowSpacing)
            )
            position.scrollTo(x: nowTarget)
        }
        .onChange(of: jumpToken) {
            // Point-scroll: the single-axis scrollTo variants reset the other
            // axis to zero, which would also fling the grid vertically.
            let target = CGPoint(x: nowTarget, y: sync.offset.y)
            #if os(tvOS)
                // Instant: the snap can span many hours, and animating it walks
                // the realization window through every hour block on the way —
                // pointless churn the Apple TV can feel.
                position.scrollTo(point: target)
            #else
                withAnimation(.easeInOut(duration: 0.4)) {
                    position.scrollTo(point: target)
                }
            #endif
        }
        .onChange(of: focusedRowIndex) { _, index in
            guard let index else { return }
            let rowStride = metrics.rowHeight + metrics.rowSpacing
            let top = CGFloat(index) * rowStride
            let bottom = top + metrics.rowHeight
            var targetY: CGFloat?
            if top < sync.offset.y {
                targetY = top
            } else if bottom > sync.offset.y + viewportHeight {
                targetY = bottom - viewportHeight
            }
            guard let targetY else { return }
            // Deferred: focus changes arrive inside the focus engine's animated
            // update; a same-frame scroll write picks up its implicit animation.
            // Point-scroll to keep the current x — scrollTo(y:) resets x to 0.
            let target = CGPoint(x: sync.offset.x, y: max(0, targetY))
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.25)) {
                    position.scrollTo(point: target)
                }
            }
        }
    }
}

/// The programme rows plus the now line. Rows realize only inside the shared
/// vertical row window and sit at their exact offsets — a `LazyVStack` here
/// instead diffed every channel's row identity on each update and did
/// per-frame bookkeeping across them all while scrolling, which large
/// categories could feel on the Apple TV.
///
/// `Equatable` (wrapped in `.equatable()` by the grid) so parent updates skip
/// this subtree unless the data or render-relevant flags changed; Observation
/// still re-runs the body directly on row-window block crossings.
private struct EPGRows: View, Equatable {
    let rows: [EPGChannelRow]
    let timeline: EPGTimeline
    let metrics: EPGMetrics
    let now: Date
    /// Observed for `rowWindow` only (per-property tracking).
    let sync: EPGScrollSync
    let dataVersion: Int
    var focusedGridRowID: FocusState<String?>.Binding
    let suppressFocusFlash: Bool
    let onPlay: (EPGChannelRow, EPGProgramCell) -> Void
    let onShowDetails: (EPGChannelRow, EPGProgramCell) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.dataVersion == rhs.dataVersion
            && lhs.rows.count == rhs.rows.count
            && lhs.suppressFocusFlash == rhs.suppressFocusFlash
            && lhs.timeline == rhs.timeline
    }

    private struct IndexedRow: Identifiable {
        let index: Int
        let row: EPGChannelRow
        var id: String {
            row.id
        }
    }

    private var rowStride: CGFloat {
        metrics.rowHeight + metrics.rowSpacing
    }

    private var contentHeight: CGFloat {
        guard !rows.isEmpty else { return 0 }
        return CGFloat(rows.count) * rowStride - metrics.rowSpacing
    }

    private var realizedRows: [IndexedRow] {
        let window = sync.rowWindow
        guard rowStride > 0, !rows.isEmpty else { return [] }
        let first = max(0, Int((window.start / rowStride).rounded(.down)))
        let last = min(rows.count - 1, Int((window.end / rowStride).rounded(.up)))
        guard first <= last else { return [] }
        return (first ... last).map { IndexedRow(index: $0, row: rows[$0]) }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(realizedRows) { entry in
                EPGProgramStrip(
                    row: entry.row,
                    timeline: timeline,
                    metrics: metrics,
                    now: now,
                    sync: sync,
                    focusedGridRowID: focusedGridRowID,
                    suppressFocusFlash: suppressFocusFlash,
                    onPlay: { cell in onPlay(entry.row, cell) },
                    onShowDetails: { cell in onShowDetails(entry.row, cell) }
                )
                .offset(y: CGFloat(entry.index) * rowStride)
            }
        }
        .frame(width: timeline.totalWidth, height: contentHeight, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            TimelineView(.everyMinute) { context in
                EPGNowIndicator(height: contentHeight)
                    .offset(x: timeline.x(for: context.date) - 4.5)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Programme strip

/// A single channel's row of programme blocks. Programmes are buttons; gaps are
/// inert. A quick click plays the channel; a long press opens the programme
/// detail sheet.
///
/// Cells are placed at their exact timeline offset, and only the ones inside
/// the shared realization window are built. A `LazyHStack` previously did the
/// windowing, but it *estimates* the extent of unrealized leading cells, and
/// with variable cell widths a row realized hours away from the origin (a
/// vertical scroll deep into the window) landed its programmes hours off the
/// ruler. Absolute placement can't misplace, and it realizes fewer focusable
/// buttons than the lazy stack's margins did — which is what keeps tvOS
/// focus-scrolling smooth (#27's stutter fix, carried over).
private struct EPGProgramStrip: View {
    let row: EPGChannelRow
    let timeline: EPGTimeline
    let metrics: EPGMetrics
    let now: Date
    /// Observed for `window` only (per-property tracking): per-frame `offset`
    /// writes never re-evaluate a row.
    let sync: EPGScrollSync
    var focusedGridRowID: FocusState<String?>.Binding
    let suppressFocusFlash: Bool
    let onPlay: (EPGProgramCell) -> Void
    let onShowDetails: (EPGProgramCell) -> Void

    /// The cells overlapping the realization window, plus one neighbour on
    /// each side. The neighbours matter for focus: from a long programme whose
    /// tail extends past the window, the *next* cell may start beyond it — if
    /// it isn't realized, the focus engine has no target and a right-press
    /// dead-ends.
    private var realizedCells: [EPGProgramCell] {
        let window = sync.window
        var result: [EPGProgramCell] = []
        var leading: EPGProgramCell?
        for cell in row.cells {
            let start = timeline.x(for: cell.start)
            let end = start + cell.width
            if start < window.end, end > window.start {
                result.append(cell)
            } else if end <= window.start {
                leading = cell
            } else {
                result.append(cell)
                break
            }
        }
        if let leading {
            result.insert(leading, at: 0)
        }
        return result
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(realizedCells) { cell in
                cellButton(cell)
                    .offset(x: timeline.x(for: cell.start))
            }
        }
        .frame(width: timeline.totalWidth, height: metrics.rowHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func cellButton(_ cell: EPGProgramCell) -> some View {
        if cell.isGap {
            // A channel with no EPG is a single full-width gap. Gaps must
            // still be focusable, playable buttons or the tvOS focus
            // engine has nothing to land on and the channel can't be
            // selected at all (#27). There's no programme to detail, so
            // gaps skip the long-press detail sheet.
            Button {
                onPlay(cell)
            } label: {
                Color.clear.frame(width: cell.width, height: metrics.rowHeight)
            }
            .buttonStyle(EPGBlockButtonStyle(cell: cell, metrics: metrics, now: now, suppressFocus: suppressFocusFlash))
            .focused(focusedGridRowID, equals: row.id)
            .accessibilityLabel(Text(row.name))
            .accessibilityHint(Text("No programme information"))
        } else {
            // Snapshot-based: cell realization runs mid-scroll, where a
            // SwiftData model read could fault to SQLite on the main thread.
            let canReplay = cell.isPast(at: now) && row.isReplayable(start: cell.start, now: now)
            Button {
                onPlay(cell)
            } label: {
                Color.clear.frame(width: cell.width, height: metrics.rowHeight)
            }
            .buttonStyle(EPGBlockButtonStyle(cell: cell, metrics: metrics, now: now, canReplay: canReplay, suppressFocus: suppressFocusFlash))
            .focused(focusedGridRowID, equals: row.id)
            // Long press (press-and-hold Select on tvOS) opens the detail
            // sheet. The gesture takes the press once it recognizes, so a
            // hold doesn't also fire the button's play action.
            .onLongPressGesture(minimumDuration: 0.4) {
                onShowDetails(cell)
            }
            .accessibilityLabel(Text(cell.title))
            .accessibilityHint(Text("\(cell.start, format: .dateTime.hour().minute()) to \(cell.end, format: .dateTime.hour().minute()) on \(row.name)"))
            .accessibilityAction(named: Text("Show Details")) { onShowDetails(cell) }
        }
    }
}
