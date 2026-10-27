import SwiftUI

@main
struct SobrApp: App {
    @StateObject private var store = SettingsStore()
    @StateObject private var session = SessionStore()
    @StateObject private var location = LocationProvider()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(session)
                .environmentObject(location)
        }
    }
}
