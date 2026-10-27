import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var session: SessionStore
    @State private var showSettings = false

    private var hasSafetyContact: Bool { !store.settings.safetyContacts.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if let end = session.endDate {
                    SessionView(end: end)
                } else {
                    startScreen
                }
            }
            .navigationTitle("Sobr")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .disabled(session.endDate != nil)   // settings are locked during a session
                }
            }
            .sheet(isPresented: $showSettings) {
                SetupView()
            }
        }
    }

    private var startScreen: some View {
        VStack(spacing: 16) {
            Spacer()

            Button {
                session.start(minutes: store.settings.soberUpMinutes)
            } label: {
                Text("I'll be drinking")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .disabled(!hasSafetyContact)

            if !hasSafetyContact {
                Text("Add at least one safety contact in settings before you start.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(SettingsStore())
        .environmentObject(SessionStore())
        .environmentObject(LocationProvider())
}
