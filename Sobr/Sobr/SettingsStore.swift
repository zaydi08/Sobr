import SwiftUI
import Combine

/// Holds the user's settings and saves them to the phone automatically.
final class SettingsStore: ObservableObject {
    @Published var settings: SobrSettings {
        didSet { save() }
    }

    private let key = "sobrSettings"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(SobrSettings.self, from: data) {
            settings = decoded
        } else {
            settings = SobrSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
