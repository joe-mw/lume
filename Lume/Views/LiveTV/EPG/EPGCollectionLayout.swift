//
//  EPGCollectionLayout.swift
//  Lume
//
//  The tvOS guide's UICollectionView layout: one section per channel, one item
//  per programme cell placed at its exact timeline offset, with the channel
//  column, time ruler and corner as supplementaries pinned to the viewport
//  edges (the sticky-header technique) and the "now" line as a decoration.
//  Everything scrolls in a single collection view, so the panes can never
//  drift out of sync and no per-frame SwiftUI mirroring exists at all.
//

#if os(tvOS)
    import UIKit

    enum EPGElementKind {
        static let channel = "epg-channel"
        static let ruler = "epg-ruler"
        static let corner = "epg-corner"
        static let nowLine = "epg-now-line"
    }

    final class EPGCollectionLayout: UICollectionViewLayout {
        var timeline: EPGTimeline?
        var metrics = EPGMetrics.current
        /// Sorted programme-cell start offsets per section, for binary search.
        private var startX: [[CGFloat]] = []
        private var cellWidths: [[CGFloat]] = []
        private var rowCount = 0
        var nowX: CGFloat = 0

        private var rowStride: CGFloat {
            metrics.rowHeight + metrics.rowSpacing
        }

        /// Rows begin below the ruler band.
        private var gridTop: CGFloat {
            metrics.headerHeight
        }

        func configure(rows: [EPGChannelRow], timeline: EPGTimeline, now: Date) {
            self.timeline = timeline
            rowCount = rows.count
            startX = rows.map { row in row.cells.map { timeline.x(for: $0.start) } }
            cellWidths = rows.map { row in row.cells.map(\.width) }
            nowX = timeline.x(for: now)
            invalidateLayout()
        }

        override var collectionViewContentSize: CGSize {
            guard let timeline else { return .zero }
            let height = gridTop + CGFloat(rowCount) * rowStride
            return CGSize(width: metrics.channelColumnWidth + timeline.totalWidth, height: height)
        }

        // MARK: - Geometry

        private func frameForItem(section: Int, item: Int) -> CGRect {
            CGRect(
                x: metrics.channelColumnWidth + startX[section][item],
                y: gridTop + CGFloat(section) * rowStride,
                width: cellWidths[section][item],
                height: metrics.rowHeight
            )
        }

        private func itemAttributes(section: Int, item: Int) -> UICollectionViewLayoutAttributes {
            let attrs = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: item, section: section))
            attrs.frame = frameForItem(section: section, item: item)
            return attrs
        }

        private func channelAttributes(section: Int, boundsOrigin: CGPoint) -> UICollectionViewLayoutAttributes {
            let attrs = UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: EPGElementKind.channel,
                with: IndexPath(item: 0, section: section)
            )
            attrs.frame = CGRect(
                x: boundsOrigin.x,
                y: gridTop + CGFloat(section) * rowStride,
                width: metrics.channelColumnWidth,
                height: metrics.rowHeight
            )
            attrs.zIndex = 10
            return attrs
        }

        private func rulerAttributes(boundsOrigin: CGPoint) -> UICollectionViewLayoutAttributes {
            let attrs = UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: EPGElementKind.ruler,
                with: IndexPath(item: 0, section: 0)
            )
            attrs.frame = CGRect(
                x: metrics.channelColumnWidth,
                y: boundsOrigin.y,
                width: timeline?.totalWidth ?? 0,
                height: metrics.headerHeight
            )
            attrs.zIndex = 15
            return attrs
        }

        private func cornerAttributes(boundsOrigin: CGPoint) -> UICollectionViewLayoutAttributes {
            let attrs = UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: EPGElementKind.corner,
                with: IndexPath(item: 0, section: 0)
            )
            attrs.frame = CGRect(
                x: boundsOrigin.x,
                y: boundsOrigin.y,
                width: metrics.channelColumnWidth,
                height: metrics.headerHeight
            )
            attrs.zIndex = 20
            return attrs
        }

        private func nowLineAttributes() -> UICollectionViewLayoutAttributes {
            let attrs = UICollectionViewLayoutAttributes(
                forDecorationViewOfKind: EPGElementKind.nowLine,
                with: IndexPath(item: 0, section: 0)
            )
            attrs.frame = CGRect(
                x: metrics.channelColumnWidth + nowX - 1,
                y: gridTop,
                width: 2,
                height: max(0, collectionViewContentSize.height - gridTop)
            )
            attrs.zIndex = 5
            return attrs
        }

        // MARK: - Layout queries

        override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            guard rowCount > 0 else { return nil }
            let boundsOrigin = collectionView?.bounds.origin ?? .zero
            var result: [UICollectionViewLayoutAttributes] = []

            let firstRow = max(0, Int(((rect.minY - gridTop) / rowStride).rounded(.down)))
            let lastRow = min(rowCount - 1, Int(((rect.maxY - gridTop) / rowStride).rounded(.up)))
            if firstRow <= lastRow {
                let minX = rect.minX - metrics.channelColumnWidth
                let maxX = rect.maxX - metrics.channelColumnWidth
                for section in firstRow ... lastRow {
                    let starts = startX[section]
                    let widths = cellWidths[section]
                    guard !starts.isEmpty else { continue }
                    // First cell whose end might reach into the rect: step back
                    // from the first start beyond minX (cells tile contiguously).
                    var index = lowerBound(starts, minX)
                    if index > 0 { index -= 1 }
                    while index < starts.count, starts[index] < maxX {
                        if starts[index] + widths[index] > minX {
                            result.append(itemAttributes(section: section, item: index))
                        }
                        index += 1
                    }
                    result.append(channelAttributes(section: section, boundsOrigin: boundsOrigin))
                }
            }

            result.append(rulerAttributes(boundsOrigin: boundsOrigin))
            result.append(cornerAttributes(boundsOrigin: boundsOrigin))
            result.append(nowLineAttributes())
            return result
        }

        override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            guard indexPath.section < rowCount, indexPath.item < startX[indexPath.section].count else { return nil }
            return itemAttributes(section: indexPath.section, item: indexPath.item)
        }

        override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            let boundsOrigin = collectionView?.bounds.origin ?? .zero
            switch elementKind {
            case EPGElementKind.channel where indexPath.section < rowCount:
                return channelAttributes(section: indexPath.section, boundsOrigin: boundsOrigin)
            case EPGElementKind.ruler:
                return rulerAttributes(boundsOrigin: boundsOrigin)
            case EPGElementKind.corner:
                return cornerAttributes(boundsOrigin: boundsOrigin)
            default:
                return nil
            }
        }

        override func layoutAttributesForDecorationView(ofKind elementKind: String, at _: IndexPath) -> UICollectionViewLayoutAttributes? {
            elementKind == EPGElementKind.nowLine ? nowLineAttributes() : nil
        }

        /// The pinned panes must re-position on every scrolled frame.
        override func shouldInvalidateLayout(forBoundsChange _: CGRect) -> Bool {
            true
        }

        /// …but only the pinned elements need re-layout, not every visible cell.
        override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
            let context = super.invalidationContext(forBoundsChange: newBounds)
            guard let collectionView, rowCount > 0 else { return context }
            let oldBounds = collectionView.bounds
            guard oldBounds.size == newBounds.size else { return context }
            let firstRow = max(0, Int(((newBounds.minY - gridTop) / rowStride).rounded(.down)))
            let lastRow = min(rowCount - 1, Int(((newBounds.maxY - gridTop) / rowStride).rounded(.up)))
            if firstRow <= lastRow {
                let paths = (firstRow ... lastRow).map { IndexPath(item: 0, section: $0) }
                context.invalidateSupplementaryElements(ofKind: EPGElementKind.channel, at: paths)
            }
            context.invalidateSupplementaryElements(ofKind: EPGElementKind.ruler, at: [IndexPath(item: 0, section: 0)])
            context.invalidateSupplementaryElements(ofKind: EPGElementKind.corner, at: [IndexPath(item: 0, section: 0)])
            return context
        }

        private func lowerBound(_ values: [CGFloat], _ target: CGFloat) -> Int {
            var low = 0
            var high = values.count
            while low < high {
                let mid = (low + high) / 2
                if values[mid] < target {
                    low = mid + 1
                } else {
                    high = mid
                }
            }
            return low
        }
    }
#endif
