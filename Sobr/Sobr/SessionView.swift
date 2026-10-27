import SwiftUI
import MessageUI
import CoreLocation

/// Wraps a text so it can drive a sheet.
struct PendingMessage: Identifiable {
    let id = UUID()
    let recipients: [String]
    let body: String
}

struct SessionView: View {
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var location: LocationProvider
    @Environment(\.openURL) private var openURL
    @StateObject private var driving = DrivingMonitor()

    let end: Date

    @State private var pending: PendingMessage?
    @State private var isPreparing = false
    @State private var showCantText = false
    @State private var showCheck = false

    private var contacts: [SafetyContact] { store.settings.safetyContacts }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                dontDriveBanner
                drivingWarning
                countdown
                helpButton
                contactList

                if store.settings.checkIsReady {
                    checkInSection
                }

                #if DEBUG
                Button("Simulate driving (debug)") { driving.simulateDriving() }
                    .buttonStyle(.bordered)
                Button("End session (testing only)") { session.end() }
                    .buttonStyle(.bordered)
                #endif
            }
            .padding()
        }
        .onAppear { driving.start() }
        .onDisappear { driving.stop() }
        .sheet(item: $pending) { message in
            MessageComposer(recipients: message.recipients, body: message.body) {
                pending = nil
            }
        }
        .sheet(isPresented: $showCheck) {
            CheckSheet(isPresented: $showCheck)
                .interactiveDismissDisabled()   // can't swipe away to dodge a failed try
        }
        .alert("This device can't send texts", isPresented: $showCantText) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Pieces

    private var dontDriveBanner: some View {
        Label("Don't drive after drinking", systemImage: "car.fill")
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var drivingWarning: some View {
        if driving.showWarning {
            VStack(spacing: 12) {
                Label("Don't drive while drinking", systemImage: "car.fill")
                    .font(.headline)
                Text("It looks like you're in a car. Please don't drive after drinking.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button("I'm not driving") { driving.dismissForThisTrip() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, end.timeIntervalSince(context.date))
            VStack(spacing: 8) {
                Text("Locks active")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(format(remaining))
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
            }
            .onChange(of: remaining) {
                if remaining <= 0 { session.end() }
            }
        }
    }

    private var helpButton: some View {
        Button {
            sendHelp(to: contacts)
        } label: {
            HStack {
                if isPreparing { ProgressView() }
                Text(isPreparing ? "Getting your location…" : "I feel unsafe: text my contacts")
                    .font(.title3.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(isPreparing || contacts.isEmpty)
    }

    private var contactList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safety contacts")
                .font(.headline)
            ForEach(contacts) { contact in
                HStack {
                    Text(contact.name)
                    Spacer()
                    Button("Call") { call(contact) }
                        .buttonStyle(.bordered)
                    Button("Text") { sendHelp(to: [contact]) }
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var checkInSection: some View {
        VStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let wait = session.nextCheckAllowedAt
                    .map { max(0, $0.timeIntervalSince(context.date)) } ?? 0
                Button {
                    showCheck = true
                } label: {
                    Text(wait > 0 ? "Next try in \(formatShort(wait))" : "Take a check-in to end early")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(wait > 0)
            }
            Text("Passing ends the session right away. Each failed try makes the wait 5 minutes longer.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    /// Gets a location (if possible), then opens the text composer, pre-filled.
    private func sendHelp(to recipients: [SafetyContact]) {
        guard MFMessageComposeViewController.canSendText() else {
            showCantText = true
            return
        }
        isPreparing = true
        Task {
            let fix = await location.currentLocation()
            pending = PendingMessage(recipients: recipients.map(\.phoneNumber),
                                     body: helpMessage(location: fix))
            isPreparing = false
        }
    }

    private func helpMessage(location: CLLocation?) -> String {
        var text = "I'm feeling unsafe and need help. Please call me."
        if let c = location?.coordinate {
            text += " My location: https://maps.apple.com/?ll=\(c.latitude),\(c.longitude)"
        } else {
            text += " (I couldn't get my location.)"
        }
        return text + " (sent from Sobr)"
    }

    /// Opens a phone call. iOS always shows a confirm prompt, so it takes one extra tap.
    private func call(_ contact: SafetyContact) {
        let digits = contact.phoneNumber.filter { "+0123456789".contains($0) }
        if let url = URL(string: "tel:\(digits)") { openURL(url) }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let t = Int(seconds)
        return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
    }

    private func formatShort(_ seconds: TimeInterval) -> String {
        let t = Int(seconds)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}
