//
//  EPGScrollSync.swift
//  Lume
//
//  The guide's shared scroll state: the raw offset the frozen panes mirror,
//  and the block-quantized realization windows the programme rows and channel
//  column realize their content inside.
//

import SwiftUI

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

// MARK: - Selection

/// A tapped programme, carried to the guide's detail sheet.
struct EPGSelection: Identifiable {
    let id: String
    let stream: LiveStream
    let cell: EPGProgramCell
}
