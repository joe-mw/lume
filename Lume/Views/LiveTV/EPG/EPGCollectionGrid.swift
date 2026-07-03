//
//  EPGCollectionGrid.swift
//  Lume
//
//  The tvOS guide grid on UICollectionView. SwiftUI's per-press focus
//  bookkeeping and per-frame view-graph work dominated device traces no
//  matter how little of the guide's own code ran; UICollectionView brings
//  native cell recycling, the focus engine's optimized collection-view path,
//  and pinned supplementaries for the frozen panes — while the cell visuals
//  stay the shared SwiftUI views via UIHostingConfiguration.
//

#if os(tvOS)
    import SwiftUI
    import UIKit

    struct EPGCollectionGrid: UIViewRepresentable {
        let rows: [EPGChannelRow]
        let timeline: EPGTimeline
        let now: Date
        let dataVersion: Int
        let nowTarget: CGFloat
        let onActivate: (EPGChannelRow, EPGProgramCell) -> Void
        let onPlayChannel: (EPGChannelRow) -> Void
        let onShowDetails: (EPGChannelRow, EPGProgramCell) -> Void

        func makeUIView(context: Context) -> EPGCollectionView {
            let layout = EPGCollectionLayout()
            let view = EPGCollectionView(frame: .zero, collectionViewLayout: layout)
            view.backgroundColor = .clear
            view.remembersLastFocusedIndexPath = false
            view.dataSource = context.coordinator
            view.delegate = context.coordinator
            view.register(EPGProgrammeCell.self, forCellWithReuseIdentifier: EPGProgrammeCell.reuseID)
            view.register(
                EPGChannelPane.self,
                forSupplementaryViewOfKind: EPGElementKind.channel,
                withReuseIdentifier: EPGChannelPane.reuseID
            )
            view.register(
                EPGRulerPane.self,
                forSupplementaryViewOfKind: EPGElementKind.ruler,
                withReuseIdentifier: EPGRulerPane.reuseID
            )
            view.register(
                EPGCornerPane.self,
                forSupplementaryViewOfKind: EPGElementKind.corner,
                withReuseIdentifier: EPGCornerPane.reuseID
            )
            layout.register(EPGNowLineView.self, forDecorationViewOfKind: EPGElementKind.nowLine)

            let longPress = UILongPressGestureRecognizer(
                target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:))
            )
            longPress.minimumPressDuration = 0.4
            view.addGestureRecognizer(longPress)

            context.coordinator.collectionView = view
            context.coordinator.apply(rows: rows, timeline: timeline, now: now, dataVersion: dataVersion, nowTarget: nowTarget)
            return view
        }

        func updateUIView(_: EPGCollectionView, context: Context) {
            context.coordinator.onActivate = onActivate
            context.coordinator.onPlayChannel = onPlayChannel
            context.coordinator.onShowDetails = onShowDetails
            context.coordinator.apply(rows: rows, timeline: timeline, now: now, dataVersion: dataVersion, nowTarget: nowTarget)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(onActivate: onActivate, onPlayChannel: onPlayChannel, onShowDetails: onShowDetails)
        }

        // MARK: - Coordinator

        final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
            var onActivate: (EPGChannelRow, EPGProgramCell) -> Void
            var onPlayChannel: (EPGChannelRow) -> Void
            var onShowDetails: (EPGChannelRow, EPGProgramCell) -> Void

            weak var collectionView: EPGCollectionView?
            private(set) var rows: [EPGChannelRow] = []
            private(set) var now = Date()
            private var metrics = EPGMetrics.current
            private var timeline: EPGTimeline?
            private var appliedDataVersion = -1
            private var didInitialScroll = false

            init(
                onActivate: @escaping (EPGChannelRow, EPGProgramCell) -> Void,
                onPlayChannel: @escaping (EPGChannelRow) -> Void,
                onShowDetails: @escaping (EPGChannelRow, EPGProgramCell) -> Void
            ) {
                self.onActivate = onActivate
                self.onPlayChannel = onPlayChannel
                self.onShowDetails = onShowDetails
            }

            func apply(rows: [EPGChannelRow], timeline: EPGTimeline, now: Date, dataVersion: Int, nowTarget: CGFloat) {
                // Guard: updateUIView fires on every SwiftUI change upstream;
                // reload only when the data actually changed.
                let signature = dataVersion == appliedDataVersion && rows.count == self.rows.count
                guard !signature, let collectionView else { return }
                appliedDataVersion = dataVersion
                self.rows = rows
                self.now = now
                self.timeline = timeline
                (collectionView.collectionViewLayout as? EPGCollectionLayout)?
                    .configure(rows: rows, timeline: timeline, now: now)
                collectionView.rowsProvider = { [weak self] in self?.rows ?? [] }
                collectionView.scrollToNow = { [weak self] animated in
                    self?.scrollToNow(nowTarget: nowTarget, animated: animated)
                }
                collectionView.reloadData()
                if !didInitialScroll, !rows.isEmpty {
                    didInitialScroll = true
                    collectionView.layoutIfNeeded()
                    scrollToNow(nowTarget: nowTarget, animated: false)
                }
            }

            private func scrollToNow(nowTarget: CGFloat, animated: Bool) {
                guard let collectionView else { return }
                let maxOffset = max(0, collectionView.contentSize.width - collectionView.bounds.width)
                let target = min(max(0, nowTarget), maxOffset)
                collectionView.setContentOffset(
                    CGPoint(x: target, y: collectionView.contentOffset.y), animated: animated
                )
            }

            // MARK: DataSource

            func numberOfSections(in _: UICollectionView) -> Int {
                rows.count
            }

            func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
                rows[section].cells.count
            }

            func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                let dequeued = collectionView.dequeueReusableCell(
                    withReuseIdentifier: EPGProgrammeCell.reuseID, for: indexPath
                )
                guard let cell = dequeued as? EPGProgrammeCell else { return dequeued }
                let row = rows[indexPath.section]
                let programme = row.cells[indexPath.item]
                let canReplay = programme.isPast(at: now) && row.isReplayable(start: programme.start, now: now)
                cell.configure(programme: programme, channelName: row.name, canReplay: canReplay, now: now, metrics: metrics)
                return cell
            }

            func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
                switch kind {
                case EPGElementKind.channel:
                    let dequeued = collectionView.dequeueReusableSupplementaryView(
                        ofKind: kind, withReuseIdentifier: EPGChannelPane.reuseID, for: indexPath
                    )
                    guard let pane = dequeued as? EPGChannelPane else { return dequeued }
                    let row = rows[indexPath.section]
                    pane.configure(row: row, metrics: metrics) { [weak self] in
                        self?.onPlayChannel(row)
                    }
                    return pane
                case EPGElementKind.ruler:
                    let dequeued = collectionView.dequeueReusableSupplementaryView(
                        ofKind: kind, withReuseIdentifier: EPGRulerPane.reuseID, for: indexPath
                    )
                    guard let pane = dequeued as? EPGRulerPane else { return dequeued }
                    if let timeline {
                        pane.configure(timeline: timeline, metrics: metrics, now: now)
                    }
                    return pane
                default:
                    return collectionView.dequeueReusableSupplementaryView(
                        ofKind: kind, withReuseIdentifier: EPGCornerPane.reuseID, for: indexPath
                    )
                }
            }

            // MARK: Delegate

            /// From the channel column, programme cells hidden behind or left
            /// of it are not valid focus targets — otherwise a left press
            /// scrolls into the past instead of exiting to the category rail.
            /// From a programme cell every item stays reachable, so walking
            /// back in time keeps working.
            func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
                guard UIFocusSystem.focusSystem(for: collectionView)?.focusedItem is EPGChannelPane,
                      let frame = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame
                else { return true }
                return frame.maxX > collectionView.bounds.origin.x + metrics.channelColumnWidth
            }

            func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
                let row = rows[indexPath.section]
                onActivate(row, row.cells[indexPath.item])
            }

            @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
                guard recognizer.state == .began,
                      let collectionView,
                      let focused = UIScreen.main.focusedView as? EPGProgrammeCell,
                      let indexPath = collectionView.indexPath(for: focused)
                else { return }
                let row = rows[indexPath.section]
                let programme = row.cells[indexPath.item]
                guard !programme.isGap else { return }
                onShowDetails(row, programme)
            }
        }
    }
#endif
