import SwiftUI

/// A frame strip whose selection changes the image shown on the canvas.
struct GIFTimeline: View {
    let frames: [GIFTimelineFrame]
    let selectedFrameIndex: Int
    let isPlaying: Bool
    let frameMaskIndices: Set<Int>
    let hasSelectedFrameMask: Bool
    let isSelectedFrameMaskEnabled: Bool
    let isFrameMaskSelected: Bool
    let canEditFrameMask: Bool
    let canToggleFrameMask: Bool
    let onSelectFrame: (Int) async -> Void
    let onTogglePlayback: () -> Void
    let onStopPlayback: () -> Void
    let onToggleFrameMask: () -> Void
    let onToggleFrameMaskEnabled: () -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var timelineDragStartOffset: CGFloat?
    @State private var scrollbarStartOffset: CGFloat?
    @State private var isTimelineDragging = false
    @State private var isScrollbarDragging = false

    private static let frameStride: CGFloat = 96
    private var contentWidth: CGFloat { CGFloat(frames.count) * Self.frameStride + 16 }
    private var isDragging: Bool { isTimelineDragging || isScrollbarDragging }
    private var canPlay: Bool { frames.count > 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onTogglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(canPlay ? Color.green : Color.secondary)
                        .frame(width: 24, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canPlay)
                .help(playbackButtonHelp)
                .accessibilityLabel(isPlaying ? "Pause GIF playback" : "Play GIF in a loop")
                .accessibilityValue(isPlaying ? "Playing" : "Paused")
                .accessibilityIdentifier("gifTimelinePlayback")
                Button(action: onToggleFrameMask) {
                    Image(systemName: "rectangle.inset.filled")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isFrameMaskSelected && !isPlaying ? Color.accentColor : Color.secondary)
                        .frame(width: 24, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isPlaying || !canEditFrameMask)
                .help(frameMaskButtonHelp)
                .accessibilityLabel(frameMaskButtonLabel)
                .accessibilityValue(isFrameMaskSelected ? "Mask selected" : "Image selected")
                .accessibilityIdentifier("gifFrameMask")
                Button(action: onToggleFrameMaskEnabled) {
                    Image(systemName: isSelectedFrameMaskEnabled ? "eye" : "eye.slash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(canToggleFrameMask && !isPlaying ? Color.secondary : Color.secondary.opacity(0.45))
                        .frame(width: 24, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isPlaying || !canToggleFrameMask)
                .help(frameMaskVisibilityHelp)
                .accessibilityLabel(frameMaskVisibilityLabel)
                .accessibilityValue(hasSelectedFrameMask ? (isSelectedFrameMaskEnabled ? "Enabled" : "Disabled") : "No mask")
                .accessibilityIdentifier("gifFrameMaskVisibility")
                Spacer()
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .help("Drag the strip or scrollbar to move through frames")
                    .accessibilityHidden(true)
                Text(isFrameMaskSelected ? "Editing mask" : "Editing frame")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("gifTimelineEditTarget")
                Divider().frame(height: 12)
                Text("\(frames.count) frames")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 26)

            Divider()

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    GIFTimelineScrollView(scrollOffset: $scrollOffset, contentWidth: contentWidth) {
                        LazyHStack(spacing: 8) {
                            ForEach(frames) { frame in
                                frameThumbnail(frame)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .frame(width: contentWidth, alignment: .leading)
                        .simultaneousGesture(timelineDragGesture(viewportWidth: geometry.size.width))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    scrollbar(viewportWidth: geometry.size.width)
                }
            }
        }
        .background(Color(white: 0.16))
        .accessibilityIdentifier("gifTimeline")
        .task(id: isPlaying) {
            await playFramesWhileNeeded()
        }
        .onDisappear {
            onStopPlayback()
        }
    }

    private func playFramesWhileNeeded() async {
        guard isPlaying, canPlay, frames.indices.contains(selectedFrameIndex) else { return }
        do {
            try await GIFPreviewPlayback.play(durations: frames.map(\.duration), startingAt: selectedFrameIndex) { index in
                await onSelectFrame(frames[index].index)
            }
        } catch {
            // Playback paused or its timeline closed.
        }
    }

    private func timelineDragGesture(viewportWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if timelineDragStartOffset == nil { timelineDragStartOffset = scrollOffset }
                isTimelineDragging = true
                guard let timelineDragStartOffset else { return }
                scrollOffset = clampedOffset(timelineDragStartOffset - value.translation.width, viewportWidth: viewportWidth)
            }
            .onEnded { _ in
                timelineDragStartOffset = nil
                isTimelineDragging = false
            }
    }

    @ViewBuilder
    private func scrollbar(viewportWidth: CGFloat) -> some View {
        let trackWidth = max(0, viewportWidth - 24)
        let maximumOffset = max(0, contentWidth - viewportWidth)
        let ratio = min(1, viewportWidth / max(1, contentWidth))
        let thumbWidth = min(trackWidth, max(min(28, trackWidth), trackWidth * ratio))

        if maximumOffset > 0, trackWidth > 0 {
            let maximumThumbOffset = max(0, trackWidth - thumbWidth)
            let thumbOffset = maximumOffset == 0 ? 0 : maximumThumbOffset * scrollOffset / maximumOffset

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(white: 0.10))
                    .frame(height: 4)

                Capsule()
                    .fill(isDragging ? Color(white: 0.76) : Color(white: 0.40))
                    .frame(height: 4)
                    .frame(width: thumbWidth, height: 14)
                    .offset(x: thumbOffset)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if scrollbarStartOffset == nil { scrollbarStartOffset = scrollOffset }
                                isScrollbarDragging = true
                                guard let scrollbarStartOffset else { return }
                                let delta = value.translation.width / max(1, maximumThumbOffset) * maximumOffset
                                scrollOffset = clampedOffset(scrollbarStartOffset + delta, viewportWidth: viewportWidth)
                            }
                            .onEnded { _ in
                                scrollbarStartOffset = nil
                                isScrollbarDragging = false
                            }
                    )
                    .accessibilityElement()
                    .accessibilityLabel("Timeline scrollbar")
                    .accessibilityValue("\(Int((scrollOffset / Self.frameStride).rounded()) + 1) of \(frames.count)")
                    .help("Drag to scroll through GIF frames")
            }
            .frame(height: 14)
            .padding(.horizontal, 12)
            .padding(.bottom, 2)
            .animation(.easeOut(duration: 0.12), value: isDragging)
        } else {
            Color.clear.frame(height: 16)
        }
    }

    private func clampedOffset(_ offset: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        min(max(0, contentWidth - viewportWidth), max(0, offset))
    }

    private var playbackButtonHelp: String {
        isPlaying ? "Pause the looping GIF." : "Play the GIF in continuous loop."
    }

    private var frameMaskButtonLabel: String {
        if hasSelectedFrameMask { return isFrameMaskSelected ? "Edit frame pixels" : "Edit this frame’s mask" }
        return "Add a mask to the selected frame"
    }

    private var frameMaskButtonHelp: String {
        guard hasSelectedFrameMask else { return "Add a mask to this frame." }
        return isFrameMaskSelected ? "Edit the frame's pixels." : "Edit this frame's mask."
    }

    private var frameMaskVisibilityLabel: String {
        guard hasSelectedFrameMask else { return "No mask on the selected frame" }
        return isSelectedFrameMaskEnabled ? "Disable this frame’s mask" : "Enable this frame’s mask"
    }

    private var frameMaskVisibilityHelp: String {
        isSelectedFrameMaskEnabled ? "Disable this frame’s mask in the canvas and exports."
            : "Enable this frame’s mask in the canvas and exports."
    }

    private func frameThumbnail(_ frame: GIFTimelineFrame) -> some View {
        let isSelected = frame.index == selectedFrameIndex
        return Button {
            Task { await onSelectFrame(frame.index) }
        } label: {
            VStack(spacing: 3) {
                Image(decorative: frame.thumbnail, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 82, height: 52)
                    .padding(3)
                    .background(Color(white: 0.22), in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(isSelected ? Color.accentColor : Color.white.opacity(0.12),
                                          lineWidth: isSelected ? 2 : 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        if frameMaskIndices.contains(frame.index) {
                            Image(systemName: "rectangle.inset.filled")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 3))
                                .padding(4)
                                .accessibilityHidden(true)
                        }
                    }
                Text("\(frame.index + 1)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(width: 88)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to display frame \(frame.index + 1) on the canvas")
        .accessibilityLabel("Frame \(frame.index + 1)")
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityIdentifier("gifTimelineFrame\(frame.index + 1)")
    }
}
