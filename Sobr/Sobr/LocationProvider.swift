import SwiftUI
import Combine
import CoreLocation

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private var pending: CheckedContinuation<CLLocation?, Never>?
    private var requestID = 0

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    var isAuthorized: Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// One location fix, or nil if unavailable or it takes longer than 6 seconds.
    func currentLocation() async -> CLLocation? {
        guard isAuthorized else { return nil }
        return await withCheckedContinuation { continuation in
            self.finish(nil)               // never leave an old request hanging
            self.requestID += 1
            let id = self.requestID
            self.pending = continuation
            self.manager.requestLocation()
            Task {
                try? await Task.sleep(for: .seconds(6))
                if id == self.requestID { self.finish(nil) }
            }
        }
    }

    private func finish(_ location: CLLocation?) {
        pending?.resume(returning: location)
        pending = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in self.finish(latest) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in self.status = newStatus }
    }
}
