import SwiftUI

/// Visualizes current relative arrangement of MacBook and Sidecar iPad in miniature and supports fine adjustment via drag.
public struct DisplayVisualizerView: View {
    public let mainDisplay: DisplayInfo?
    public let sidecarDisplay: DisplayInfo?
    /// Whether mirroring is active. Mirroring represents one logical screen rather than two, so only a single card is drawn.
    public let isMirrored: Bool
    public let onDragEnded: ((TargetDisplayOrigin) -> Void)?

    private let transformer: CoordinateTransforming

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    public init(
        mainDisplay: DisplayInfo?,
        sidecarDisplay: DisplayInfo?,
        isMirrored: Bool = false,
        transformer: CoordinateTransforming = MiniatureCoordinateTransformer(),
        onDragEnded: ((TargetDisplayOrigin) -> Void)? = nil
    ) {
        self.mainDisplay = mainDisplay
        self.sidecarDisplay = sidecarDisplay
        self.isMirrored = isMirrored
        self.transformer = transformer
        self.onDragEnded = onDragEnded
    }

    public var body: some View {
        GeometryReader { geometry in
            let canvasSize = geometry.size
            let (mainRect, sidecarRect, scale) = calculateMiniatureRects(in: canvasSize)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                // During mirroring, both displays report identical bounds. Drawing two would overlap
                // exactly and stack text. Since there is only one screen, a single card is drawn.
                if isMirrored, let mainRect = mainRect {
                    HStack(spacing: 6) {
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 14))
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "ipad.landscape")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(.primary)
                    .frame(width: mainRect.width, height: mainRect.height)
                    .background(Color.green.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.green, lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .position(x: mainRect.midX, y: mainRect.midY)
                }

                if !isMirrored, let mainRect = mainRect {
                    // Main MacBook display miniature
                    VStack(spacing: 2) {
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                        Text("MacBook")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(width: mainRect.width, height: mainRect.height)
                    .background(Color.blue.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue, lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .position(x: mainRect.midX, y: mainRect.midY)
                }

                if !isMirrored, let sidecarRect = sidecarRect {
                    // Sidecar iPad display miniature (draggable)
                    VStack(spacing: 2) {
                        Image(systemName: "ipad.landscape")
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                        Text("iPad")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(width: sidecarRect.width, height: sidecarRect.height)
                    .background(Color.green.opacity(isDragging ? 0.3 : 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.green, lineWidth: isDragging ? 2.5 : 1.5)
                    )
                    .shadow(color: isDragging ? Color.green.opacity(0.4) : Color.clear, radius: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .offset(dragOffset)
                    .position(x: sidecarRect.midX, y: sidecarRect.midY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                isDragging = false
                                if let sidecar = sidecarDisplay {
                                    let newOrigin = transformer.transformDragToTargetOrigin(
                                        currentOrigin: sidecar.bounds.origin,
                                        dragTranslation: value.translation,
                                        scale: scale
                                    )
                                    dragOffset = .zero
                                    onDragEnded?(newOrigin)
                                } else {
                                    dragOffset = .zero
                                }
                            }
                    )
                }
            }
        }
        .frame(height: 120)
    }

    /// Calculates scaled CGRects and scale factor for main display and Sidecar relative to canvas size.
    private func calculateMiniatureRects(in size: CGSize) -> (CGRect?, CGRect?, CGFloat) {
        guard let main = mainDisplay else { return (nil, nil, 1.0) }

        var allRects = [main.bounds]
        if let sidecar = sidecarDisplay, !isMirrored {
            allRects.append(sidecar.bounds)
        }

        // Calculate overall bounding box
        let minX = allRects.map { $0.minX }.min() ?? 0
        let maxX = allRects.map { $0.maxX }.max() ?? 100
        let minY = allRects.map { $0.minY }.min() ?? 0
        let maxY = allRects.map { $0.maxY }.max() ?? 100

        let totalWidth = max(maxX - minX, 1)
        let totalHeight = max(maxY - minY, 1)

        let padding: CGFloat = 16
        let availableWidth = size.width - (padding * 2)
        let availableHeight = size.height - (padding * 2)

        let scale = min(availableWidth / totalWidth, availableHeight / totalHeight)

        let offsetX = (size.width - (totalWidth * scale)) / 2 - (minX * scale)
        let offsetY = (size.height - (totalHeight * scale)) / 2 - (minY * scale)

        let scaledMain = CGRect(
            x: offsetX + (main.bounds.origin.x * scale),
            y: offsetY + (main.bounds.origin.y * scale),
            width: main.bounds.width * scale,
            height: main.bounds.height * scale
        )

        let scaledSidecar: CGRect?
        if let sidecar = sidecarDisplay {
            scaledSidecar = CGRect(
                x: offsetX + (sidecar.bounds.origin.x * scale),
                y: offsetY + (sidecar.bounds.origin.y * scale),
                width: sidecar.bounds.width * scale,
                height: sidecar.bounds.height * scale
            )
        } else {
            scaledSidecar = nil
        }

        return (scaledMain, scaledSidecar, scale)
    }
}
