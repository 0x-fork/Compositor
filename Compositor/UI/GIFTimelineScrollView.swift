import AppKit
import SwiftUI

/// A horizontal hosted view without a native scroller; GIFTimeline draws its own styled scrollbar.
struct GIFTimelineScrollView<Content: View>: NSViewRepresentable {
    @Binding var scrollOffset: CGFloat
    let contentWidth: CGFloat
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator(scrollOffset: $scrollOffset) }

    func makeNSView(context: Context) -> Container {
        let view = Container(rootView: AnyView(content().frame(width: contentWidth)), contentWidth: contentWidth)
        view.onScrollOffsetChanged = { [weak coordinator = context.coordinator] offset in
            coordinator?.updateScrollOffset(offset)
        }
        return view
    }

    func updateNSView(_ view: Container, context: Context) {
        view.onScrollOffsetChanged = { [weak coordinator = context.coordinator] offset in
            coordinator?.updateScrollOffset(offset)
        }
        view.update(rootView: AnyView(content().frame(width: contentWidth)), contentWidth: contentWidth)
        view.setScrollOffset(scrollOffset)
    }

    final class Coordinator {
        private var scrollOffset: Binding<CGFloat>

        init(scrollOffset: Binding<CGFloat>) { self.scrollOffset = scrollOffset }

        func updateScrollOffset(_ offset: CGFloat) {
            guard abs(scrollOffset.wrappedValue - offset) > 0.5 else { return }
            scrollOffset.wrappedValue = offset
        }
    }

    final class Container: NSScrollView {
        private let host: NSHostingView<AnyView>
        private var contentWidth: CGFloat
        private var boundsObserver: NSObjectProtocol?
        var onScrollOffsetChanged: ((CGFloat) -> Void)?

        init(rootView: AnyView, contentWidth: CGFloat) {
            host = NSHostingView(rootView: rootView)
            self.contentWidth = contentWidth
            super.init(frame: .zero)
            drawsBackground = false
            borderType = .noBorder
            hasHorizontalScroller = false
            hasVerticalScroller = false
            horizontalScrollElasticity = .none
            verticalScrollElasticity = .none
            documentView = host
            contentView.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification, object: contentView, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.onScrollOffsetChanged?(self.contentView.bounds.origin.x)
            }
            updateContentSize()
        }

        required init?(coder: NSCoder) { nil }

        deinit {
            if let boundsObserver { NotificationCenter.default.removeObserver(boundsObserver) }
        }

        override func layout() {
            super.layout()
            updateContentSize()
        }

        func update(rootView: AnyView, contentWidth: CGFloat) {
            host.rootView = rootView
            host.invalidateIntrinsicContentSize()
            self.contentWidth = contentWidth
            updateContentSize()
        }

        func setScrollOffset(_ offset: CGFloat) {
            let maximumOffset = max(0, host.frame.width - contentView.bounds.width)
            let x = min(maximumOffset, max(0, offset))
            guard abs(contentView.bounds.origin.x - x) > 0.5 else { return }
            contentView.scroll(to: NSPoint(x: x, y: 0))
            reflectScrolledClipView(contentView)
        }

        private func updateContentSize() {
            let viewport = contentView.bounds.size
            let size = NSSize(width: max(contentWidth, viewport.width), height: max(host.fittingSize.height, viewport.height))
            if host.frame.size != size { host.setFrameSize(size) }
            setScrollOffset(contentView.bounds.origin.x)
        }
    }
}
