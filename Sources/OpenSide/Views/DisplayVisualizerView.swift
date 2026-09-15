import SwiftUI

/// 맥북과 사이드카 아이패드의 현재 상대적 배치를 미니어처 형태로 시각화하고 마우스 드래그 미세 정렬을 지원하는 뷰
public struct DisplayVisualizerView: View {
    public let mainDisplay: DisplayInfo?
    public let sidecarDisplay: DisplayInfo?
    public let onDragEnded: ((TargetDisplayOrigin) -> Void)?

    private let transformer: CoordinateTransforming

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    public init(
        mainDisplay: DisplayInfo?,
        sidecarDisplay: DisplayInfo?,
        transformer: CoordinateTransforming = MiniatureCoordinateTransformer(),
        onDragEnded: ((TargetDisplayOrigin) -> Void)? = nil
    ) {
        self.mainDisplay = mainDisplay
        self.sidecarDisplay = sidecarDisplay
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

                if let mainRect = mainRect {
                    // 메인 맥북 디스플레이 미니어처
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

                if let sidecarRect = sidecarRect {
                    // 사이드카 아이패드 디스플레이 미니어처 (드래그 가능)
                    VStack(spacing: 2) {
                        Image(systemName: "ipad.landscape")
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                        Text("Sidecar")
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

    /// 캔버스 크기 대비 메인 디스플레이와 사이드카의 축소된 CGRect 및 스케일 배율 계산
    private func calculateMiniatureRects(in size: CGSize) -> (CGRect?, CGRect?, CGFloat) {
        guard let main = mainDisplay else { return (nil, nil, 1.0) }

        var allRects = [main.bounds]
        if let sidecar = sidecarDisplay {
            allRects.append(sidecar.bounds)
        }

        // 전체 bounding box 계산
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
