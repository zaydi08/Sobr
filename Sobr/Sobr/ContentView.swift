import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        if store.settings.hasCompletedSetup {
            HomeView()
        } else {
            SetupView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsStore())
        .environmentObject(SessionStore())
}
