import SwiftUI
import Combine

/// Tracks the running session, including failed check-ins and the cooldown.
final class SessionStore: ObservableObject {
    static let cooldownStepMinutes = 5

    @Published private(set) var endDate: Date?
    @Published private(set) var failedChecks = 0
    @Published private(set) var nextCheckAllowedAt: Date?

    private struct Saved: Codable {
        var endDate: Date
        var failedChecks: Int
        var nextCheckAllowedAt: Date?
    }

    private let key = "sobrSession"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              saved.endDate > Date() else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        endDate = saved.endDate
        failedChecks = saved.failedChecks
        nextCheckAllowedAt = saved.nextCheckAllowedAt
    }

    func start(minutes: Int) {
        endDate = Date().addingTimeInterval(Double(minutes) * 60)
        failedChecks = 0
        nextCheckAllowedAt = nil
        persist()
    }

    func end() {
        endDate = nil
        failedChecks = 0
        nextCheckAllowedAt = nil
        persist()
    }

    /// Each failure makes the wait 5 minutes longer: 5, 10, 15, ...
    func recordFailure() {
        failedChecks += 1
        let wait = Double(failedChecks * Self.cooldownStepMinutes * 60)
        nextCheckAllowedAt = Date().addingTimeInterval(wait)
        persist()
    }

    private func persist() {
        guard let endDate else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        let saved = Saved(endDate: endDate,
                          failedChecks: failedChecks,
                          nextCheckAllowedAt: nextCheckAllowedAt)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
