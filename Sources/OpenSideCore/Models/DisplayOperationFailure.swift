import Foundation

/// Reasons why a display operation failed.
///
/// The view model holds error cases rather than pre-formatted strings, allowing the view
/// to construct messages in the selected language. Holding static localized strings in the view model
/// would leave error messages in the old language when switching languages.
public enum DisplayOperationFailure: Equatable, Sendable {
    /// Could not find Sidecar display
    case noSidecarDisplay
    /// Could not find main display
    case noMainDisplay
    /// CoreGraphics rejected the display configuration
    case configuration(DisplayConfigurationError)

    /// Formats the error message for the selected language
    public func message(_ strings: LocalizedUIStrings) -> String {
        switch self {
        case .noSidecarDisplay: return strings.noSidecarDisplayError
        case .noMainDisplay: return strings.noMainDisplayError
        case .configuration(let error): return strings.displayConfigurationError(error)
        }
    }
}
