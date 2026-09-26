import Foundation

/// Rules defining which display is identified as Sidecar.
///
/// Separated from CoreGraphics calls to enable headless unit testing.
public enum SidecarDisplayRule {

    /// Display names assigned by macOS to Sidecar screens.
    private static let names = ["sidecar", "ipad", "airplay"]

    /// - Parameters:
    ///   - name: Name reported by NSScreen. Fallback names are supplied when NSScreen drops mirrored screens.
    ///   - isOurs: Whether the display is a virtual canvas created by this app.
    ///   - hasSidecarSession: Whether an active Sidecar session is currently running.
    public static func isSidecar(
        name: String,
        isBuiltin: Bool,
        isOurs: Bool,
        isMirrored: Bool,
        hasSidecarSession: Bool
    ) -> Bool {
        guard !isBuiltin, !isOurs else { return false }

        let lower = name.lowercased()
        if names.contains(where: lower.contains) { return true }

        // When mirroring, NSScreen omits this display, preventing its name from being read.
        // While unnamed mirrored screens should therefore be considered Sidecar candidates,
        // that rule alone would misidentify an external HDMI monitor as the iPad when mirrored.
        // We only apply this fallback if an active session is verified.
        //
        // Mirroring both an iPad and an external monitor simultaneously remains unresolved;
        // macOS groups them into a single mirror set, leaving no distinct clues.
        return isMirrored && hasSidecarSession
    }
}
