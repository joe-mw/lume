//
//  EPGFocusStrip.swift
//  Lume
//
//  The tvOS guide's single real focus target plus its edge sentinels. The
//  engine only consults `shouldUpdateFocus` when a move has a candidate
//  target — with nothing focusable inside the guide, moves towards its
//  interior would be silently ignored. The sentinels hug the strip so every
//  interior direction always yields a proposal; the veto then reads the
//  move's *heading* (not which view the engine picked) and forwards it to the
//  guide's virtual navigation, covering remote presses *and* swipes even when
//  a strong neighbour like the tab bar is the engine's proposed target.
//
//  The one move that leaves the guide is left from the channel hub. A
//  full-height view projects its focus from screen centre, so the engine
//  finds no candidate on the top-aligned rail; and driving the SwiftUI rail's
//  focus state from here loses a fight with the UIKit strip (focus falls back
//  to the tab bar). So a `UIFocusGuide` at the leading edge points at the
//  rail's *container* view (the left-adjacent sibling, found by walking up):
//  the engine descends into it and focuses a category — pure UIKit, no
//  SwiftUI focus fight, and independent of where focus entered from.
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

        /// The strip, its interior sentinels, and the left-exit guide.
        final class ContainerView: UIView {
            let strip = StripView()
            private var sentinels: [MoveCommandDirection: SentinelView] = [:]
            /// The guaranteed left candidate when leaving the hub; targets the
            /// rail's container so the engine descends and focuses a category.
            private let exitGuide = UIFocusGuide()

            override init(frame: CGRect) {
                super.init(frame: frame)
                for direction: MoveCommandDirection in [.up, .down, .left, .right] {
                    let sentinel = SentinelView()
                    sentinel.strip = strip
                    sentinels[direction] = sentinel
                    addSubview(sentinel)
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
                strip.exitsLeft = exits
                // On the hub the left sentinel yields to the exit guide so a
                // left move leaves; on a cell it stays as the interior veto.
                sentinels[.left]?.isFocusEnabled = !exits
                if exits, let rail = railContainer() {
                    exitGuide.preferredFocusEnvironments = [rail]
                    exitGuide.isEnabled = true
                } else {
                    exitGuide.isEnabled = false
                }
            }

            /// The rail's container: the *leftmost* sibling lying wholly to the
            /// strip's left, across every ancestor level. Taking the smallest
            /// `minX` skips the guide's own channel column (a nearer left
            /// sibling) and reaches the rail outside the guide. Walked from the
            /// tree so the UIKit strip needs no direct reference to the SwiftUI
            /// rail; pointing a focus guide at the container (not a leaf) lets
            /// the engine descend and focus the rail's remembered category.
            private func railContainer() -> UIFocusEnvironment? {
                guard let window else { return nil }
                let stripFrame = strip.convert(strip.bounds, to: window)
                var best: UIView?
                var bestMinX = CGFloat.greatestFiniteMagnitude
                var node: UIView = self
                while let parent = node.superview {
                    for sibling in parent.subviews where sibling !== node {
                        let frame = sibling.convert(sibling.bounds, to: window)
                        if frame.maxX <= stripFrame.minX + 1, frame.width > 100, frame.height > 100,
                           frame.minX < bestMinX
                        {
                            best = sibling
                            bestMinX = frame.minX
                        }
                    }
                    node = parent
                }
                return best
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
        /// it guarantees every interior direction has something to move
        /// toward (triggering the veto) without stealing entry focus.
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
            /// Whether a left move leaves the guide (hub) or navigates (cell).
            var exitsLeft = false

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
                    onFocusChange?(true)
                } else if context.previouslyFocusedView === self {
                    isEngineFocused = false
                    onFocusChange?(false)
                }
            }

            override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
                guard isEngineFocused, context.previouslyFocusedView === self else { return true }
                // After a veto the engine synchronously retries with further
                // candidates; without this the same press would fire a second
                // action and let the retry carry real focus out of the guide.
                if moveConsumed { return false }
                // Decide from the *heading*, not from which view the engine
                // proposed: near a strong external neighbour (the tab bar
                // above, the rail beside) the engine may target it rather than
                // our edge sentinel, but the move is still ours to interpret.
                guard let direction = Self.direction(from: context.focusHeading) else { return true }
                // Left from the hub leaves the guide: allow the move so the
                // engine carries focus to the exit guide (→ the rail).
                if direction == .left, exitsLeft { return true }
                // Every other direction stays inside: veto and navigate
                // virtually, even when the engine targeted the tab bar.
                moveConsumed = true
                Task { @MainActor in
                    self.moveConsumed = false
                    self.onMove?(direction)
                }
                return false
            }

            private static func direction(from heading: UIFocusHeading) -> MoveCommandDirection? {
                switch heading {
                case .up: .up
                case .down: .down
                case .left: .left
                case .right: .right
                default: nil
                }
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
