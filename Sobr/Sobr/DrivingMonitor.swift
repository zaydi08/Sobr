import SwiftUI
import Combine
import CoreMotion

@MainActor
final class DrivingMonitor: ObservableObject {
    /// True when the phone seems to be in a car and the user hasn't dismissed it for this trip.
    @Published private(set) var showWarning = false

    private static let tripEndDelay: Double = 120   // seconds out of the car before the trip counts as over

    private let manager = CMMotionActivityManager()
    private var inCar = false
    private var dismissedThisTrip = false
    private var tripEndTask: Task<Void, Never>?

    func start() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            let driving = activity.automotive && activity.confidence != .low
            Task { @MainActor in self?.handle(driving: driving) }
        }
    }

    func stop() {
        manager.stopActivityUpdates()
        tripEndTask?.cancel()
        tripEndTask = nil
        inCar = false
        dismissedThisTrip = false
        showWarning = false
    }

    /// The user tapped "I'm not driving". Quiet for the rest of this trip.
    func dismissForThisTrip() {
        dismissedThisTrip = true
        showWarning = false
    }

    private func handle(driving: Bool) {
        if driving {
            tripEndTask?.cancel()
            tripEndTask = nil
            inCar = true
            showWarning = !dismissedThisTrip
        } else if inCar && tripEndTask == nil {
            // Not in a car right now. Only call the trip over if it stays that way.
            tripEndTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(DrivingMonitor.tripEndDelay))
                guard !Task.isCancelled, let self else { return }
                self.inCar = false
                self.dismissedThisTrip = false
                self.showWarning = false
                self.tripEndTask = nil
            }
        }
    }

    #if DEBUG
    /// Lets you see the warning in the simulator.
    func simulateDriving() { handle(driving: true) }
    #endif
}
