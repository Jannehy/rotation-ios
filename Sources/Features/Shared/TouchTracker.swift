import SwiftUI
import UIKit

/// Reports where a finger is, but only once it is clearly reading the chart.
///
/// The rule is the one the Android client uses, and that turned out to be the
/// better one: a finger moving up or down belongs to the page, a finger moving
/// left or right belongs to the chart. Nothing happens on touch down, so a
/// scroll that starts on top of a chart behaves like a scroll anywhere else.
///
/// A pan recogniser can decide this at the moment it would begin: if the
/// movement is more vertical than horizontal it never starts, and the scroll
/// view carries on undisturbed. Once it does start, scrolling is switched off
/// for its duration, so the value under the finger cannot slide away while it
/// is being read. A plain tap also picks a value, and leaves it standing.
///
/// The clock is round, so reading it means moving in every direction. There a
/// long press opens the same tracking instead – `.longPressDrag`.
struct TouchTracker: UIViewRepresentable {
    enum Mode {
        /// Sideways swipe, plus tap. For charts laid out along an axis.
        case sideways
        /// Press and hold, then move any way. For the round clock.
        case longPressDrag
    }

    var mode: Mode = .sideways
    var onChange: (CGPoint) -> Void
    var onEnd: () -> Void = {}

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let coordinator = context.coordinator

        switch mode {
        case .sideways:
            let pan = UIPanGestureRecognizer(
                target: coordinator, action: #selector(Coordinator.handlePan(_:)))
            pan.delegate = coordinator
            // The chart reads one finger; two of them are a system gesture.
            pan.minimumNumberOfTouches = 1
            pan.maximumNumberOfTouches = 1
            view.addGestureRecognizer(pan)

            let tap = UITapGestureRecognizer(
                target: coordinator, action: #selector(Coordinator.handleTap(_:)))
            view.addGestureRecognizer(tap)

        case .longPressDrag:
            let press = UILongPressGestureRecognizer(
                target: coordinator, action: #selector(Coordinator.handlePress(_:)))
            press.minimumPressDuration = 0.25
            press.allowableMovement = .greatestFiniteMagnitude
            press.delegate = coordinator
            view.addGestureRecognizer(press)
        }
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onEnd = onEnd
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onEnd: onEnd)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChange: (CGPoint) -> Void
        var onEnd: () -> Void
        /// The scroll view that was paused, so exactly that one is resumed.
        private weak var paused: UIScrollView?

        init(onChange: @escaping (CGPoint) -> Void, onEnd: @escaping () -> Void) {
            self.onChange = onChange
            self.onEnd = onEnd
        }

        @objc func handlePan(_ recogniser: UIPanGestureRecognizer) {
            track(recogniser)
        }

        @objc func handlePress(_ recogniser: UILongPressGestureRecognizer) {
            track(recogniser)
        }

        /// A tap picks a value and leaves it standing – no `onEnd`.
        @objc func handleTap(_ recogniser: UITapGestureRecognizer) {
            onChange(recogniser.location(in: recogniser.view))
        }

        private func track(_ recogniser: UIGestureRecognizer) {
            switch recogniser.state {
            case .began:
                pauseScrolling(around: recogniser.view)
                onChange(recogniser.location(in: recogniser.view))
            case .changed:
                onChange(recogniser.location(in: recogniser.view))
            case .ended, .cancelled, .failed:
                resumeScrolling()
                onEnd()
            default:
                break
            }
        }

        /// Only a sideways swipe is meant for the chart.
        func gestureRecognizerShouldBegin(_ recogniser: UIGestureRecognizer) -> Bool {
            guard let pan = recogniser as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        private func pauseScrolling(around view: UIView?) {
            var next = view?.superview
            while let current = next {
                if let scroll = current as? UIScrollView, scroll.isScrollEnabled {
                    scroll.isScrollEnabled = false
                    paused = scroll
                    return
                }
                next = current.superview
            }
        }

        private func resumeScrolling() {
            paused?.isScrollEnabled = true
            paused = nil
        }
    }
}

extension View {
    /// Reads a value along this chart: swipe sideways, or tap.
    func trackTouches(onMove: @escaping (CGPoint) -> Void,
                      onEnd: @escaping () -> Void = {}) -> some View {
        overlay(TouchTracker(mode: .sideways, onChange: onMove, onEnd: onEnd))
    }

    /// Reads a value anywhere on this chart, after a press and hold.
    func trackTouchesAfterLongPress(onMove: @escaping (CGPoint) -> Void,
                                    onEnd: @escaping () -> Void = {}) -> some View {
        overlay(TouchTracker(mode: .longPressDrag, onChange: onMove, onEnd: onEnd))
    }
}
