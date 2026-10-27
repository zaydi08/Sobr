import SwiftUI

struct SetupView: View {
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var location: LocationProvider
    @Environment(\.dismiss) private var dismiss
    @State private var newApp = ""
    @State private var showPicker = false
    @State private var showBaseline = false

    private var isBlockAll: Bool { store.settings.mode == .blockAllExcept }

    /// The list that matches the currently selected mode.
    private var activeList: Binding<[String]> {
        isBlockAll ? $store.settings.blockAllExceptApps : $store.settings.allowAllExceptApps
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lock mode") {
                    Picker("Mode", selection: $store.settings.mode) {
                        Text("Block all except").tag(LockMode.blockAllExcept)
                        Text("Allow all except").tag(LockMode.allowAllExcept)
                    }
                    .pickerStyle(.segmented)

                    Text(isBlockAll
                         ? "Everything is locked except the apps you pick."
                         : "Only the apps you pick are locked.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(isBlockAll ? "Apps that stay open" : "Apps to lock") {
                    ForEach(activeList.wrappedValue, id: \.self) { app in
                        Text(app)
                    }
                    .onDelete { activeList.wrappedValue.remove(atOffsets: $0) }

                    HStack {
                        TextField(isBlockAll ? "e.g. Uber, Maps" : "e.g. DoorDash, Instagram",
                                  text: $newApp)
                        Button("Add") {
                            let name = newApp.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty,
                                  !activeList.wrappedValue.contains(name) else { return }
                            activeList.wrappedValue.append(name)
                            newApp = ""
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Section("Safety contacts (up to \(SobrSettings.maxSafetyContacts))") {
                    ForEach(store.settings.safetyContacts) { contact in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(contact.name)
                                Text(contact.phoneNumber)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                store.settings.safetyContacts.removeAll { $0.id == contact.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(contact.name)")
                        }
                    }
                    .onDelete { store.settings.safetyContacts.remove(atOffsets: $0) }

                    if store.settings.safetyContacts.count < SobrSettings.maxSafetyContacts {
                        Button("Add from Contacts") { showPicker = true }
                    }
                }

                Section("Location for safety messages") {
                    if location.isAuthorized {
                        Label("Location is on", systemImage: "checkmark.circle.fill")
                    } else {
                        Button("Allow location") { location.requestPermission() }
                        Text("Only used when you tap the safety button, to add a map link. If you denied it before, turn it on in the iPhone Settings app under Sobr.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sober-up timer") {
                    Stepper(value: $store.settings.soberUpMinutes, in: 30...720, step: 30) {
                        Text("\(store.settings.soberUpMinutes / 60)h \(store.settings.soberUpMinutes % 60)m")
                    }
                }

                Section("Check-in") {
                    Picker("Method", selection: $store.settings.checkMethod) {
                        ForEach(CheckMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }

                    if store.settings.checkMethod == .reaction {
                        if let baseline = store.settings.reactionBaseline {
                            Label("Baseline: \(Int(baseline.medianMs.rounded())) ms",
                                  systemImage: "checkmark.circle.fill")
                            Button("Redo baseline") { showBaseline = true }
                        } else {
                            Button("Record baseline (required)") { showBaseline = true }
                        }
                    }

                    Text("During a session, passing the check-in ends it early. " + Disclaimer.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Save settings") {
                        store.settings.hasCompletedSetup = true
                        dismiss()
                    }
                    .disabled(store.settings.needsBaseline)

                    if store.settings.needsBaseline {
                        Text("Record your baseline to use the reaction game.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Set up Sobr")
            .sheet(isPresented: $showPicker) {
                ContactPicker(
                    onPick: { name, number in
                        let alreadyAdded = store.settings.safetyContacts.contains { $0.phoneNumber == number }
                        if !alreadyAdded {
                            store.settings.safetyContacts.append(SafetyContact(name: name, phoneNumber: number))
                        }
                        showPicker = false
                    },
                    onCancel: { showPicker = false }
                )
            }
            .sheet(isPresented: $showBaseline) {
                ReactionCheckView(
                    title: "Record your baseline",
                    intro: "Do this while you're sober, so Sobr knows your normal speed. The screen will turn green at a random moment. Tap as fast as you can.",
                    totalTrials: ReactionRules.trialsPerRound * ReactionRules.baselineRounds,
                    onFinish: { result in
                        store.settings.reactionBaseline = ReactionBaseline(medianMs: result.medianMs)
                        showBaseline = false
                    },
                    onCancel: { _ in showBaseline = false }
                )
            }
        }
    }
}

#Preview {
    SetupView()
        .environmentObject(SettingsStore())
        .environmentObject(LocationProvider())
}
