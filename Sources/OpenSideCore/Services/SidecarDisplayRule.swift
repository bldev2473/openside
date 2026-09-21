import Foundation

/// 어떤 화면을 사이드카로 볼지 가리는 규칙.
///
/// 화면 없이 시험할 수 있도록 CoreGraphics 호출과 떼어 둡니다.
public enum SidecarDisplayRule {

    /// macOS 가 이 화면에 붙이는 이름들.
    private static let names = ["sidecar", "ipad", "airplay"]

    /// - Parameters:
    ///   - name: NSScreen 이 준 이름. 복제 중에는 화면을 안 내놓으므로 대체 이름이 옵니다.
    ///   - isOurs: 이 앱이 만들어 띄운 화면인지.
    ///   - hasSidecarSession: 지금 사이드카 세션이 붙어 있는지.
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

        // 복제 중에는 NSScreen 이 이 화면을 내놓지 않아 이름을 못 읽습니다. 그래서 이름이
        // 없는 복제 화면도 사이드카로 봐야 하는데, 그 규칙만으로는 HDMI 로 붙인 모니터를
        // 복제로 쓸 때 그 모니터가 iPad 로 잡힙니다. 세션이 붙어 있을 때만 적용합니다.
        //
        // iPad 와 외장 모니터를 동시에 복제로 두면 여전히 가리지 못합니다. 그 경우 macOS 도
        // 두 화면을 같은 복제 집합으로 묶어 내놓으므로 우리가 쥘 단서가 없습니다.
        return isMirrored && hasSidecarSession
    }
}
