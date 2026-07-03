//
//  EPGFrozenPanes.swift
//  Lume
//
//  The guide's frozen edges: the time ruler across the top and the channel
//  column on the left. Both mirror the grid's scroll offset via the shared
//  sync; the column's cells realize only inside the quantized row window. On
//  tvOS the column doubles as the guide's focus hub.
//

import SwiftUI

// MARK: - Ruler strip

/// The time ruler, shifted to mirror the grid's horizontal offset. Observes the
/// shared sync so only its offset updates while scrolling — the ruler's own
/// content is built once.
struct EPGRulerStrip: View {
    let timeline: EPGTimeline
    let metrics: EPGMetrics
    let now: Date
    let sync: EPGScrollSync

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: metrics.headerHeight)
            .overlay(alignment: .leading) {
                ZStack(alignment: .topLeading) {
                    EPGTimeRuler(timeline: timeline, metrics: metrics)
                    nowPill.offset(x: timeline.x(for: now))
                }
                .frame(width: timeline.totalWidth, alignment: .leading)
                .offset(x: -sync.offset.x)
            }
            .clipped()
    }

    private var nowPill: some View {
        Text("Now")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.red))
            .fixedSize()
            .alignmentGuide(.leading) { $0.width / 2 }
    }
}

// MARK: - Frozen column

/// The channel column, shifted to mirror the grid's vertical offset. Built once;
/// only the offset modifier changes as the grid scrolls.
///
/// On tvOS the column is the guide's navigation hub: its cells are focusable
/// buttons (select plays the channel), the category rail sits one left-press
/// away and the programme grid one right-press away. The column itself never
/// scrolls — `EPGGridScroller` scrolls the grid to follow the focused channel,
/// and this view mirrors that offset.
struct EPGFrozenColumn: View {
    let rows: [EPGChannelRow]
    let metrics: EPGMetrics
    let sync: EPGScrollSync
    #if os(tvOS)
        let onPlay: (EPGChannelRow) -> Void
        var focusedChannelID: FocusState<String?>.Binding
    #endif

    var body: some View {
        Color.clear
            .frame(width: metrics.channelColumnWidth)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .top) {
                // The offset lives here, on the parent that observes it, while
                // the cells are a separate child keyed off the quantized row
                // window — a per-frame offset write shifts the child without
                // re-running its body (a re-diff of one item per channel, per
                // frame, on big categories otherwise).
                columnCells
                    .offset(y: -sync.offset.y)
            }
            .clipped()
        #if !os(tvOS)
            // The channel cards on tvOS already read as a separate rail, so
            // a vertical rule would only add visual weight.
            .overlay(alignment: .trailing) { Rectangle().fill(.quaternary).frame(width: 1) }
        #endif
    }

    @ViewBuilder
    private var columnCells: some View {
        #if os(tvOS)
            EPGColumnCells(rows: rows, metrics: metrics, sync: sync, onPlay: onPlay, focusedChannelID: focusedChannelID)
                .equatable()
        #else
            EPGColumnCells(rows: rows, metrics: metrics, sync: sync)
                .equatable()
        #endif
    }
}

/// The column's channel cells, realized only inside the shared vertical row
/// window and placed at their exact offsets — a plain `VStack` over every
/// channel built one focusable button (and one logo load) per channel up
/// front, which is what made large categories heavy on tvOS.
///
/// `Equatable` (and wrapped in `.equatable()` by the parent) so the parent's
/// per-frame offset re-evaluation skips this body: the stored closures defeat
/// SwiftUI's reflection-based comparison otherwise. Observation still re-runs
/// the body directly whenever `rowWindow` changes, independent of the parent.
struct EPGColumnCells: View, Equatable {
    let rows: [EPGChannelRow]
    let metrics: EPGMetrics
    /// Observed for `rowWindow` only (per-property tracking).
    let sync: EPGScrollSync
    #if os(tvOS)
        let onPlay: (EPGChannelRow) -> Void
        var focusedChannelID: FocusState<String?>.Binding
    #endif

    /// Within one guide instance the row set only changes on a listings
    /// reload (same channels, new cells) — and the column renders channel
    /// identity only, so boundary ids + count identify the set.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rows.count == rhs.rows.count
            && lhs.rows.first?.id == rhs.rows.first?.id
            && lhs.rows.last?.id == rhs.rows.last?.id
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
                cell(entry.row)
                    .offset(y: CGFloat(entry.index) * rowStride)
            }
        }
        .frame(
            width: metrics.channelColumnWidth,
            height: max(0, CGFloat(rows.count) * rowStride - metrics.rowSpacing),
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private func cell(_ row: EPGChannelRow) -> some View {
        #if os(tvOS)
            Button {
                onPlay(row)
            } label: {
                Color.clear.frame(width: metrics.channelColumnWidth, height: metrics.rowHeight)
            }
            .buttonStyle(EPGChannelButtonStyle(row: row, metrics: metrics))
            .focused(focusedChannelID, equals: row.id)
            .accessibilityLabel(Text(row.name))
        #else
            EPGChannelCell(row: row, metrics: metrics)
        #endif
    }
}
