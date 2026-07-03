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

// MARK: - Selection

/// A tapped programme, carried to the detail sheet.
private struct EPGSelection: Identifiable {
    let id: String
    let stream: LiveStream
    let cell: EPGProgramCell
}

// MARK: - Scroll sync

/// Shared, observable scroll offset. Only the ruler and channel column observe
/// it, so panning the grid updates *their* offset modifiers without re-running
/// the (expensive) programme grid. See `skills/swiftui-performance.md`.
///
/// `window` is the horizontal realization window for programme rows and
/// `rowWindow` the vertical one for the channel column, both quantized to
/// blocks so they change on block crossings — not per scrolled frame.
/// Observation tracks the properties independently: the ruler/column offsets
/// read only `offset`, the rows read only `window`, the column cells only
/// `rowWindow`, so per-frame offset writes never re-evaluate a row or cell.
@MainActor
@Observable
final class EPGScrollSync {
    var offset = CGPoint.zero
    var window = EPGRealizeWindow(start: 0, end: 0)
    var rowWindow = EPGRealizeWindow(start: 0, end: 0)
}

/// The range along one scroll axis worth realizing: the viewport plus one
/// block on both sides, snapped to block boundaries.
struct EPGRealizeWindow: Equatable {
    var start: CGFloat
    var end: CGFloat

    static func around(offset: CGFloat, viewport: CGFloat, blockLength: CGFloat) -> EPGRealizeWindow {
        let start = ((offset - blockLength) / blockLength).rounded(.down) * blockLength
        let end = ((offset + viewport + blockLength) / blockLength).rounded(.up) * blockLength
        return EPGRealizeWindow(start: max(0, start), end: max(0, end))
    }
}

// MARK: - Scroller

/// Lays out the frozen panes (corner, ruler, channel column) beside the single
/// scrollable grid. The same layout serves every platform: touch and pointer
/// drag the grid, tvOS moves it by focus, and the frozen column sits *beside*
/// the grid so a focused programme is never hidden behind it.
struct EPGGridScroller: View {
    let rows: [EPGChannelRow]
    let timeline: EPGTimeline
    let onPlay: (LiveStream) -> Void
    let onPlayCatchup: (LiveStream, EPGProgramCell) -> Void

    private let metrics = EPGMetrics.current
    private let now = Date()

    @State private var sync = EPGScrollSync()
    @State private var selection: EPGSelection?
    @State private var jumpToken = 0
    #if os(tvOS)
        /// The focused channel-column row. The column is the tvOS navigation
        /// hub: focus lands here on entry, and Menu from inside the grid
        /// returns here instead of leaving the screen.
        @FocusState private var focusedChannelID: String?
        /// When the column last handed focus away, so grid focus arriving
        /// right afterwards can be told apart from focus entering the guide
        /// from outside (see the bounce in `body`).
        @State private var columnLostFocusAt: Date?
        /// True while focus sits outside the guide: grid cells render
        /// unfocused during it, so the bounce's transient grid focus never
        /// flashes — the user only sees the channel light up.
        @State private var entryGrace = true
    #endif
    /// Which row's programme currently holds focus, reported by every cell
    /// button (used by the tvOS Menu escape and entry bounce).
    @FocusState private var focusedGridRowID: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header: corner + time ruler. Touch/pointer get a jump-to-now
            // button in the corner; tvOS auto-scrolls to now on appear and has
            // no use for a corner button it can't easily reach, so the corner
            // is left empty there.
            HStack(spacing: 0) {
                corner
                    .frame(width: metrics.channelColumnWidth, height: metrics.headerHeight)

                EPGRulerStrip(timeline: timeline, metrics: metrics, now: now, sync: sync)
            }
            .frame(height: metrics.headerHeight)

            #if !os(tvOS)
                Divider()
            #endif

            // Body: frozen channel column + scrollable programme grid.
            HStack(spacing: 0) {
                #if os(tvOS)
                    EPGFrozenColumn(
                        rows: rows,
                        metrics: metrics,
                        sync: sync,
                        onPlay: { onPlay($0.stream) },
                        focusedChannelID: $focusedChannelID
                    )
                #else
                    EPGFrozenColumn(rows: rows, metrics: metrics, sync: sync)
                #endif

                EPGGrid(
                    rows: rows,
                    timeline: timeline,
                    metrics: metrics,
                    now: now,
                    sync: sync,
                    jumpToken: jumpToken,
                    nowTarget: nowScrollTarget,
                    focusedRowIndex: focusedRowIndex,
                    focusedGridRowID: $focusedGridRowID,
                    suppressFocusFlash: suppressFocusFlash,
                    onExit: exitGridFocus,
                    // A past programme still inside the channel's archive plays
                    // as catch-up; everything else plays the channel live.
                    onPlay: { row, cell in
                        if !cell.isGap, cell.isPast(at: now),
                           PlayableMedia.isCatchupAvailable(stream: row.stream, start: cell.start, now: now)
                        {
                            onPlayCatchup(row.stream, cell)
                        } else {
                            onPlay(row.stream)
                        }
                    },
                    onShowDetails: { row, cell in
                        selection = EPGSelection(id: cell.id, stream: row.stream, cell: cell)
                    }
                )
            }
        }
        #if os(tvOS)
        // Land on the channel column when the guide first receives focus (from
        // the tab bar or the category rail): channels are directly selectable,
        // the rail is one left-press away, the programmes one right-press.
        // `.userInitiated` so the suggestion also wins the scene's initial
        // focus resolution, which otherwise picks a programme cell.
        .defaultFocus($focusedChannelID, rows.first?.id, priority: .userInitiated)
        .onChange(of: focusedChannelID) { old, new in
            if old != nil, new == nil {
                columnLostFocusAt = Date()
                if focusedGridRowID == nil {
                    entryGrace = true
                }
            } else if new != nil {
                entryGrace = false
            }
        }
        // Entry bounce. The focus engine refuses directional entry into the
        // column's cells (regardless of hosting, sections, styles, or scopes —
        // all verified on-device) and always drops rail/tab-bar entries onto a
        // programme cell. When grid focus arrives without the column having
        // *just* handed it over, treat it as an entry from outside and move
        // focus to the same row's channel cell, keeping the column the hub.
        .onChange(of: focusedGridRowID) { old, new in
            if old != nil, new == nil, focusedChannelID == nil {
                entryGrace = true
                return
            }
            guard old == nil, let new else { return }
            let handoff = columnLostFocusAt.map { Date().timeIntervalSince($0) < 0.3 } ?? false
            guard !handoff else {
                entryGrace = false
                return
            }
            // The transient grid focus may have dragged the window towards the
            // cell the engine picked; entering fresh should read as "now".
            // `entryGrace` stays on until the channel lands, so the transient
            // cell renders unfocused throughout.
            jumpToken += 1
            focusedChannelID = new
            Task { @MainActor in
                if focusedChannelID != new {
                    focusedChannelID = new
                }
            }
        }
        #else
        .background(.background)
        #endif
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

    /// Scroll offset that places "now" just inside the leading edge of the grid.
    private var nowScrollTarget: CGFloat {
        max(0, timeline.x(for: now) - 12)
    }

    /// While focus is outside the guide (tvOS), grid cells render unfocused so
    /// the entry bounce's transient focus never flashes.
    private var suppressFocusFlash: Bool {
        #if os(tvOS)
            entryGrace
        #else
            false
        #endif
    }

    /// Index of the channel-column row holding focus, so the grid can scroll
    /// vertically to keep it visible (the column itself is not scrollable).
    private var focusedRowIndex: Int? {
        #if os(tvOS)
            guard let focusedChannelID else { return nil }
            return rows.firstIndex { $0.id == focusedChannelID }
        #else
            return nil
        #endif
    }

    /// Menu pressed while focus is inside the programme grid: instead of
    /// leaving the screen, snap the window back to "now" and land focus on the
    /// focused programme's own channel (or the top visible one as a fallback) —
    /// one press escapes any scroll depth, and the category rail is then a
    /// single left-press away.
    private func exitGridFocus(from gridRowID: String?) {
        #if os(tvOS)
            jumpToken += 1
            let rowStride = metrics.rowHeight + metrics.rowSpacing
            let topIndex = max(0, min(rows.count - 1, Int((sync.offset.y / rowStride).rounded())))
            let fallback = rows.indices.contains(topIndex) ? rows[topIndex].id : nil
            guard let target = gridRowID ?? fallback else { return }
            // Same-cycle write first (no intermediate frame); the exit command
            // arrives inside the focus engine's update, where a same-frame
            // focus write can be dropped — the deferred pass re-asserts it.
            focusedChannelID = target
            Task { @MainActor in
                if focusedChannelID != target {
                    focusedChannelID = target
                }
            }
        #else
            _ = gridRowID
        #endif
    }

    @ViewBuilder
    private var corner: some View {
        #if os(tvOS)
            Color.clear
        #else
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
        #endif
    }
}

// MARK: - Grid

/// The single scrollable surface. Owns its scroll position (used only for
/// programmatic jump-to-now) and publishes its offset to the shared sync. Its
/// programme rows live in a separate child so the per-frame scroll-position
/// write-back never rebuilds them.
private struct EPGGrid: View {
    let rows: [EPGChannelRow]
    let timeline: EPGTimeline
    let metrics: EPGMetrics
    let now: Date
    let sync: EPGScrollSync
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
                focusedGridRowID: focusedGridRowID,
                suppressFocusFlash: suppressFocusFlash,
                onPlay: onPlay,
                onShowDetails: onShowDetails
            )
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
                blockLength: 60 * metrics.pointsPerMinute
            )
            if sync.window != window {
                sync.window = window
            }
            let rowWindow = EPGRealizeWindow.around(
                offset: max(0, new.origin.y),
                viewport: new.height,
                blockLength: 4 * (metrics.rowHeight + metrics.rowSpacing)
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
                blockLength: 60 * metrics.pointsPerMinute
            )
            sync.rowWindow = EPGRealizeWindow.around(
                offset: 0,
                viewport: 1400,
                blockLength: 4 * (metrics.rowHeight + metrics.rowSpacing)
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

/// The programme rows plus the now line. Free of any per-frame scroll-offset
/// dependency, so it builds once and lazily loads rows as they scroll into
/// view; the strips inside re-realize their cells only on hour-block crossings.
private struct EPGRows: View {
    let rows: [EPGChannelRow]
    let timeline: EPGTimeline
    let metrics: EPGMetrics
    let now: Date
    let sync: EPGScrollSync
    var focusedGridRowID: FocusState<String?>.Binding
    let suppressFocusFlash: Bool
    let onPlay: (EPGChannelRow, EPGProgramCell) -> Void
    let onShowDetails: (EPGChannelRow, EPGProgramCell) -> Void

    private var contentHeight: CGFloat {
        guard !rows.isEmpty else { return 0 }
        return CGFloat(rows.count) * metrics.rowHeight + CGFloat(rows.count - 1) * metrics.rowSpacing
    }

    var body: some View {
        LazyVStack(spacing: metrics.rowSpacing) {
            ForEach(rows) { row in
                EPGProgramStrip(
                    row: row,
                    timeline: timeline,
                    metrics: metrics,
                    now: now,
                    sync: sync,
                    focusedGridRowID: focusedGridRowID,
                    suppressFocusFlash: suppressFocusFlash,
                    onPlay: { cell in onPlay(row, cell) },
                    onShowDetails: { cell in onShowDetails(row, cell) }
                )
            }
        }
        .frame(width: timeline.totalWidth, alignment: .topLeading)
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

    private var realizedCells: [EPGProgramCell] {
        let window = sync.window
        return row.cells.filter { cell in
            let start = timeline.x(for: cell.start)
            return start < window.end && start + cell.width > window.start
        }
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
            let canReplay = cell.isPast(at: now)
                && PlayableMedia.isCatchupAvailable(stream: row.stream, start: cell.start, now: now)
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
