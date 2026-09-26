import AppKit

/// Menu bar icon. Renders the layout matching the app logo as line art.
///
/// Menu bar images are templates and cannot use color. macOS tints them automatically
/// based on menu bar appearance, so we provide outline shapes only. Logo's blue and green colors do not apply here.
public enum MenuBarIcon {

    /// Aspect ratios matching the logo.
    private static let macRatio: CGFloat = 1512.0 / 982.0
    private static let padRatio: CGFloat = 1112.0 / 834.0

    /// - Parameter showsSidecar: Whether iPad is connected. If connected, draws an additional screen,
    ///   maintaining distinction formerly represented by display vs display.2.
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

            // MacBook at top-left, iPad at bottom-right. Same composition as the logo.
            let mac = NSRect(x: inset, y: size.height - macHeight - inset,
                             width: macWidth, height: macHeight)
            let macPath = NSBezierPath(roundedRect: mac, xRadius: 1.5, yRadius: 1.5)
            macPath.lineWidth = line
            macPath.stroke()

            if showsSidecar {
                let pad = NSRect(x: size.width - padWidth - inset, y: inset,
                                 width: padWidth, height: padHeight)
                let padPath = NSBezierPath(roundedRect: pad, xRadius: 1.2, yRadius: 1.2)

                // Clear overlapping area first. Crossing lines left as-is would appear clumped together.
                // Same layering order as the logo where iPad sits atop MacBook.
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
