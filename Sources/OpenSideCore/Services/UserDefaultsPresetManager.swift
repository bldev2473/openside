import Foundation

/// UserDefaults-based implementation for persisting arrangement presets and settings
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
