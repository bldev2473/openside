import Foundation

/// UserDefaults를 이용한 프리셋 및 설정 영속화 서비스 구현체
public struct UserDefaultsPresetManager: @unchecked Sendable, PresetManaging {
    private let userDefaults: UserDefaults
    private let lastPresetKey = "OpenSide.lastArrangementPreset"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func saveLastPreset(_ preset: DisplayArrangementPreset) {
        userDefaults.set(preset.rawValue, forKey: lastPresetKey)
    }

    public func loadLastPreset() -> DisplayArrangementPreset? {
        guard let rawValue = userDefaults.string(forKey: lastPresetKey) else {
            return nil
        }
        return DisplayArrangementPreset(rawValue: rawValue)
    }

    public func clearLastPreset() {
        userDefaults.removeObject(forKey: lastPresetKey)
    }
}
