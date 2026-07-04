//
//  EPGFocusStrip.swift
//  Lume
//
//  The tvOS guide's single real focus target plus its edge sentinels. The
//  engine only consults `shouldUpdateFocus` when a move has a candidate
//  target — with nothing focusable inside the guide, moves towards its
//  interior would be silently ignored. The sentinels hug the strip so every
//  interior direction always yields a proposal: proposals onto a sentinel are
//  vetoed and forwarded to the guide's virtual navigation (covering remote
//  presses *and* swipes).
//
//  Leaving the guide is a separate mechanism: a full-height view projects its
//  focus from screen centre, so a plain leftward move rarely finds the rail.
//  A `UIFocusGuide` pinned to the leading edge, targeting the view focus came
//  *from* (the rail item), makes the left exit land exactly back where the
//  user entered — deterministically, and without any programmatic focus
//  transfer (which the engine drops when made from its own callbacks).
//

#if os(tvOS)
    import SwiftUI
    import UIKit

    struct EPGFocusStrip: UIViewRepresentable {
        /// Reflects the strip's real (engine) focus.
        @Binding var isFocused: Bool
        /// Whether a left move should leave the guide (channel hub) rather
        /// than navigate virtually (programme cells).
        let exitsLeft: Bool
        /// Handles a consumed directional move.
        let onMove: (MoveCommandDirection) -> Void
        let onSelect: () -> Void
        let onLongSelect: () -> Void
        /// Returns whether the Menu press was consumed.
        let onMenu: () -> Bool

        func makeUIView(context _: Context) -> ContainerView {
            let view = ContainerView()
            apply(to: view)
            return view
        }

        func updateUIView(_ view: ContainerView, context _: Context) {
            apply(to: view)
        }

        private func apply(to view: ContainerView) {
            view.strip.onFocusChange = { focused in
                Task { @MainActor in
                    isFocused = focused
                }
            }
            view.strip.onMove = onMove
            view.strip.onSelect = onSelect
            view.strip.onLongSelect = onLongSelect
            view.strip.onMenu = onMenu
            view.setExitsLeft(exitsLeft)
        }

        /// The strip, its interior sentinels, and the leading exit guide.
        final class ContainerView: UIView {
            let strip = StripView()
            private var sentinels: [MoveCommandDirection: SentinelView] = [:]
            /// Redirects a left exit back to the rail item focus came from.
            private let exitGuide = UIFocusGuide()
            private var exitsLeft = false

            override init(frame: CGRect) {
                super.init(frame: frame)
                for direction: MoveCommandDirection in [.up, .down, .left, .right] {
                    let sentinel = SentinelView()
                    sentinel.strip = strip
                    sentinels[direction] = sentinel
                    addSubview(sentinel)
                }
                strip.sentinelDirection = { [weak self] view in
                    self?.sentinels.first { $0.value === view }?.key
                }
                // Remember where focus came from so the left exit returns there.
                strip.onEnter = { [weak self] origin in
                    guard let self, let origin, !(origin is SentinelView) else { return }
                    exitGuide.preferredFocusEnvironments = [origin]
                    updateExitGuide()
                }
                addSubview(strip)

                addLayoutGuide(exitGuide)
                exitGuide.isEnabled = false
                NSLayoutConstraint.activate([
                    exitGuide.leadingAnchor.constraint(equalTo: leadingAnchor),
                    exitGuide.topAnchor.constraint(equalTo: topAnchor),
                    exitGuide.bottomAnchor.constraint(equalTo: bottomAnchor),
                    exitGuide.widthAnchor.constraint(equalToConstant: 2)
                ])
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            func setExitsLeft(_ exits: Bool) {
                exitsLeft = exits
                // The left sentinel (interior veto) and the exit guide occupy
                // the same leading strip; exactly one is active at a time.
                sentinels[.left]?.isFocusEnabled = !exits
                updateExitGuide()
            }

            private func updateExitGuide() {
                exitGuide.isEnabled = exitsLeft && !exitGuide.preferredFocusEnvironments.isEmpty
            }

            override func layoutSubviews() {
                super.layoutSubviews()
                let inset: CGFloat = 2
                strip.frame = bounds.insetBy(dx: inset, dy: inset)
                sentinels[.up]?.frame = CGRect(x: inset, y: 0, width: bounds.width - 2 * inset, height: inset)
                sentinels[.down]?.frame = CGRect(x: inset, y: bounds.height - inset, width: bounds.width - 2 * inset, height: inset)
                sentinels[.left]?.frame = CGRect(x: 0, y: inset, width: inset, height: bounds.height - 2 * inset)
                sentinels[.right]?.frame = CGRect(x: bounds.width - inset, y: inset, width: inset, height: bounds.height - 2 * inset)
            }
        }

        /// A proposal target the strip vetoes moves onto; never actually
        /// focused. Only a candidate while the strip itself holds focus, so
        /// entry into the guide always lands on the strip.
        final class SentinelView: UIView {
            var isFocusEnabled = true
            weak var strip: StripView?

            override init(frame: CGRect) {
                super.init(frame: frame)
                backgroundColor = UIColor.white.withAlphaComponent(0.01)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            override var canBecomeFocused: Bool {
                isFocusEnabled && strip?.isEngineFocused == true
            }
        }

        final class StripView: UIView {
            var onFocusChange: ((Bool) -> Void)?
            var onMove: ((MoveCommandDirection) -> Void)?
            var onSelect: (() -> Void)?
            var onLongSelect: (() -> Void)?
            var onMenu: (() -> Bool)?
            /// Called when focus enters the strip, with the view it came from.
            var onEnter: ((UIFocusEnvironment?) -> Void)?
            /// Resolves a proposed focus target to the sentinel direction it
            /// represents, if any.
            var sentinelDirection: ((UIView) -> MoveCommandDirection?)?

            private(set) var isEngineFocused = false
            private var longPressFired = false
            private var moveConsumed = false

            override init(frame: CGRect) {
                super.init(frame: frame)
                // Near-invisible but non-zero: fully transparent views are
                // dropped from the engine's directional candidacy.
                backgroundColor = UIColor.white.withAlphaComponent(0.01)

                let select = UITapGestureRecognizer(target: self, action: #selector(handleSelect))
                select.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
                addGestureRecognizer(select)

                let long = UILongPressGestureRecognizer(target: self, action: #selector(handleLongSelect(_:)))
                long.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
                long.minimumPressDuration = 0.4
                addGestureRecognizer(long)
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            override var canBecomeFocused: Bool {
                true
            }

            override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
                super.didUpdateFocus(in: context, with: coordinator)
                if context.nextFocusedView === self {
                    isEngineFocused = true
                    onEnter?(context.previouslyFocusedView)
                    onFocusChange?(true)
                } else if context.previouslyFocusedView === self {
                    isEngineFocused = false
                    onFocusChange?(false)
                }
            }

            override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
                guard isEngineFocused, context.previouslyFocusedView === self else { return true }
                // After a veto the engine synchronously retries with further
                // candidates; without this the same press would both fire a
                // second virtual move and let the retry carry real focus out
                // of the guide.
                if moveConsumed { return false }
                guard let next = context.nextFocusedView,
                      let direction = sentinelDirection?(next)
                else { return true }
                // A move onto a sentinel is ours: veto the real focus change
                // and navigate virtually instead. Deferred — the veto runs
                // inside the engine's update.
                moveConsumed = true
                Task { @MainActor in
                    self.moveConsumed = false
                    self.onMove?(direction)
                }
                return false
            }

            override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
                guard isEngineFocused, presses.contains(where: { $0.type == .menu }) else {
                    return super.pressesBegan(presses, with: event)
                }
                if onMenu?() != true {
                    super.pressesBegan(presses, with: event)
                }
            }

            @objc private func handleSelect() {
                guard !longPressFired else {
                    longPressFired = false
                    return
                }
                onSelect?()
            }

            @objc private func handleLongSelect(_ recognizer: UILongPressGestureRecognizer) {
                guard recognizer.state == .began else { return }
                longPressFired = true
                onLongSelect?()
            }
        }
    }
#endif
