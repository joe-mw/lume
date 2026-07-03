//
//  EPGCollectionViews.swift
//  Lume
//
//  The UIKit pieces of the tvOS guide grid: the collection-view subclass that
//  routes entry focus onto the channel column and turns Menu into "back to
//  now + my channel", the programme cell, and the pinned panes. Cell and pane
//  content is the shared SwiftUI views, hosted via UIHostingConfiguration.
//

#if os(tvOS)
    import SwiftUI
    import UIKit

    // MARK: - Collection view

    final class EPGCollectionView: UICollectionView {
        /// Set by the coordinator so focus routing can reach the data.
        var rowsProvider: () -> [EPGChannelRow] = { [] }
        var scrollToNow: (Bool) -> Void = { _ in }

        /// One-shot focus target for the Menu redirect.
        private var redirectSection: Int?
        /// True while a Menu press we consumed is in flight.
        private var handlingMenu = false

        private var focusedView: UIView? {
            UIFocusSystem.focusSystem(for: self)?.focusedItem as? UIView
        }

        private var epgLayout: EPGCollectionLayout? {
            collectionViewLayout as? EPGCollectionLayout
        }

        /// The section whose row sits at the top of the viewport.
        private var topVisibleSection: Int? {
            let rows = rowsProvider()
            guard !rows.isEmpty else { return nil }
            let metrics = EPGMetrics.current
            let offsetY = contentOffset.y
            let index = Int(((offsetY - metrics.headerHeight) / (metrics.rowHeight + metrics.rowSpacing)).rounded())
            return max(0, min(rows.count - 1, index))
        }

        private func channelPane(for section: Int) -> EPGChannelPane? {
            supplementaryView(
                forElementKind: EPGElementKind.channel,
                at: IndexPath(item: 0, section: section)
            ) as? EPGChannelPane
        }

        /// Entry from the rail or tab bar lands on the channel column, and the
        /// Menu redirect targets the focused row's channel — native focus
        /// routing instead of the SwiftUI-era bounce.
        override var preferredFocusEnvironments: [UIFocusEnvironment] {
            if let section = redirectSection {
                redirectSection = nil
                if let pane = channelPane(for: section) {
                    return [pane]
                }
            }
            if let focused = focusedView, focused.isDescendant(of: self) {
                return super.preferredFocusEnvironments
            }
            if let section = topVisibleSection, let pane = channelPane(for: section) {
                return [pane]
            }
            return super.preferredFocusEnvironments
        }

        /// Menu inside the programme grid: snap back to now and land focus on
        /// the focused row's channel. Menu on the channel column falls through
        /// to the default (exits towards the rail / tab bar).
        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            guard presses.contains(where: { $0.type == .menu }),
                  let cell = focusedView as? EPGProgrammeCell,
                  let indexPath = indexPath(for: cell)
            else {
                super.pressesBegan(presses, with: event)
                return
            }
            handlingMenu = true
            redirectSection = indexPath.section
            scrollToNow(false)
            setNeedsFocusUpdate()
            updateFocusIfNeeded()
        }

        override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if handlingMenu, presses.contains(where: { $0.type == .menu }) {
                handlingMenu = false
                return
            }
            super.pressesEnded(presses, with: event)
        }

        override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            handlingMenu = false
            super.pressesCancelled(presses, with: event)
        }
    }

    // MARK: - Programme cell

    final class EPGProgrammeCell: UICollectionViewCell {
        static let reuseID = "EPGProgrammeCell"

        private var programme: EPGProgramCell?
        private var channelName = ""
        private var canReplay = false
        private var now = Date()
        private var metrics = EPGMetrics.current

        func configure(programme: EPGProgramCell, channelName: String, canReplay: Bool, now: Date, metrics: EPGMetrics) {
            self.programme = programme
            self.channelName = channelName
            self.canReplay = canReplay
            self.now = now
            self.metrics = metrics
            render(focused: isFocused)
        }

        private func render(focused: Bool) {
            guard let programme else { return }
            contentConfiguration = UIHostingConfiguration {
                EPGProgramBlockView(
                    cell: programme,
                    metrics: metrics,
                    now: now,
                    isFocused: focused,
                    canReplay: canReplay
                )
            }
            .margins(.all, 0)
            if let programme = self.programme {
                isAccessibilityElement = true
                accessibilityLabel = programme.isGap ? channelName : programme.title
            }
        }

        override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            super.didUpdateFocus(in: context, with: coordinator)
            let focused = isFocused
            render(focused: focused)
            coordinator.addCoordinatedAnimations {
                self.transform = focused ? CGAffineTransform(scaleX: 1.04, y: 1.04) : .identity
                self.layer.shadowColor = UIColor.black.cgColor
                self.layer.shadowOpacity = focused ? 0.4 : 0
                self.layer.shadowRadius = 10
                self.layer.shadowOffset = CGSize(width: 0, height: 6)
            }
        }
    }

    // MARK: - Channel pane

    final class EPGChannelPane: UICollectionReusableView {
        static let reuseID = "EPGChannelPane"

        private var row: EPGChannelRow?
        private var metrics = EPGMetrics.current
        private var onSelect: () -> Void = {}
        private var hosted: (UIView & UIContentView)?
        private let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

        override init(frame: CGRect) {
            super.init(frame: frame)
            backdrop.frame = bounds
            backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(backdrop)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        override var canBecomeFocused: Bool {
            true
        }

        func configure(row: EPGChannelRow, metrics: EPGMetrics, onSelect: @escaping () -> Void) {
            self.row = row
            self.metrics = metrics
            self.onSelect = onSelect
            render(focused: isFocused)
        }

        private func render(focused: Bool) {
            guard let row else { return }
            let configuration = UIHostingConfiguration {
                EPGChannelCell(row: row, metrics: metrics, isFocused: focused)
            }
            .margins(.all, 0)
            if let hosted {
                hosted.configuration = configuration
            } else {
                let view = configuration.makeContentView()
                view.frame = bounds
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(view)
                hosted = view
            }
            isAccessibilityElement = true
            accessibilityLabel = row.name
        }

        override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            super.didUpdateFocus(in: context, with: coordinator)
            render(focused: isFocused)
        }

        override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if isFocused, presses.contains(where: { $0.type == .select }) {
                onSelect()
                return
            }
            super.pressesEnded(presses, with: event)
        }
    }

    // MARK: - Ruler + corner panes

    final class EPGRulerPane: UICollectionReusableView {
        static let reuseID = "EPGRulerPane"

        private var hosted: (UIView & UIContentView)?
        private let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

        override init(frame: CGRect) {
            super.init(frame: frame)
            backdrop.frame = bounds
            backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(backdrop)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        func configure(timeline: EPGTimeline, metrics: EPGMetrics, now: Date) {
            let configuration = UIHostingConfiguration {
                ZStack(alignment: .topLeading) {
                    EPGTimeRuler(timeline: timeline, metrics: metrics)
                    EPGNowPill()
                        .offset(x: timeline.x(for: now))
                }
                .frame(width: timeline.totalWidth, alignment: .leading)
            }
            .margins(.all, 0)
            if let hosted {
                hosted.configuration = configuration
            } else {
                let view = configuration.makeContentView()
                view.frame = bounds
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(view)
                hosted = view
            }
        }
    }

    final class EPGCornerPane: UICollectionReusableView {
        static let reuseID = "EPGCornerPane"

        override init(frame: CGRect) {
            super.init(frame: frame)
            let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
            backdrop.frame = bounds
            backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(backdrop)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }
    }

    // MARK: - Now line

    final class EPGNowLineView: UICollectionReusableView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }
    }
#endif
