import Foundation

/// Interface for receiving Sidecar battery updates
public protocol BatteryReceiving: AnyObject {
    /// Callback closure invoked when battery updates arrive.
    /// Passes nil if the iPad can no longer be read, preventing the UI from showing stale values.
    var onBatteryUpdate: ((SidecarBatteryInfo?) -> Void)? { get set }

    /// Starts listening for battery updates
    func startListening()

    /// Stops listening for battery updates
    func stopListening()
}

/// Interface for estimating remaining battery runtime.
///
/// Because estimation relies on historical session data, the concrete implementation is injected by consuming apps.
public protocol RemainingTimeEstimating: AnyObject {
    /// Estimated remaining usage time in seconds for the current battery level. Nil if insufficient samples.
    func estimatedRemaining(currentBattery: Int) -> TimeInterval?
}
