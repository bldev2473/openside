import AppKit

/// 메뉴바에 놓는 아이콘. 앱 로고와 같은 배치를 선만 남겨 그립니다.
///
/// 메뉴바 이미지는 템플릿이라 색을 쓸 수 없습니다. macOS 가 메뉴바 밝기에 맞춰 알아서
/// 칠하므로, 우리는 모양만 남기고 색은 넘깁니다. 로고의 파랑과 초록은 여기서 사라집니다.
public enum MenuBarIcon {

    /// 로고와 같은 화면 비율.
    private static let macRatio: CGFloat = 1512.0 / 982.0
    private static let padRatio: CGFloat = 1112.0 / 834.0

    /// - Parameter showsSidecar: iPad 가 붙어 있는지. 붙어 있으면 화면을 하나 더 그려,
    ///   여태 쓰던 display 와 display.2 의 구분을 잇습니다.
    public static func image(showsSidecar: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 13)
        let line: CGFloat = 1.2
        let inset = line / 2

        let macWidth: CGFloat = 15
        let macHeight = macWidth / macRatio
        let padWidth: CGFloat = 9.4
        let padHeight = padWidth / padRatio

        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setStroke()

            // MacBook 은 좌측 상단, iPad 는 우측 하단. 로고와 같은 구도입니다.
            let mac = NSRect(x: inset, y: size.height - macHeight - inset,
                             width: macWidth, height: macHeight)
            let macPath = NSBezierPath(roundedRect: mac, xRadius: 1.5, yRadius: 1.5)
            macPath.lineWidth = line
            macPath.stroke()

            if showsSidecar {
                let pad = NSRect(x: size.width - padWidth - inset, y: inset,
                                 width: padWidth, height: padHeight)
                let padPath = NSBezierPath(roundedRect: pad, xRadius: 1.2, yRadius: 1.2)

                // 겹치는 자리를 먼저 지웁니다. 두 선이 교차한 채 남으면 그 부분만 뭉쳐 보입니다.
                // 로고에서 iPad 가 MacBook 위에 오는 것과 같은 순서입니다.
                NSGraphicsContext.current?.compositingOperation = .clear
                padPath.fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver

                padPath.lineWidth = line
                padPath.stroke()
            }

            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = "OpenSide"
        return image
    }
}
