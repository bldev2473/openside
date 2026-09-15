import Foundation
import Combine

/// 애플리케이션 언어 설정 관리 인터페이스
public protocol LanguageManaging: AnyObject, Sendable {
    /// 현재 선택된 언어
    var currentLanguage: AppLanguage { get }

    /// 언어 변경 및 저장
    func setLanguage(_ language: AppLanguage)
}

/// UserDefaults 기반 언어 설정 영속화 구현체
public final class UserDefaultsLanguageManager: ObservableObject, LanguageManaging, @unchecked Sendable {
    public static let shared = UserDefaultsLanguageManager()

    private let userDefaults: UserDefaults
    private let storageKey = "OpenSide.SelectedLanguage"

    @Published public private(set) var currentLanguage: AppLanguage

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let savedCode = userDefaults.string(forKey: storageKey),
           let language = AppLanguage(rawValue: savedCode) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .korean
        }
    }

    /// 언어 변경 및 설정값 저장
    public func setLanguage(_ language: AppLanguage) {
        self.currentLanguage = language
        userDefaults.set(language.rawValue, forKey: storageKey)
    }
}
