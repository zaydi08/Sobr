import SwiftUI

struct CheckSheet: View {
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var session: SessionStore
    @Binding var isPresented: Bool

    @State private var outcome: CheckOutcome?

    var body: some View {
        if let result = outcome {
            CheckResultView(
                outcome: result,
                retryMinutes: session.failedChecks * SessionStore.cooldownStepMinutes
            ) {
                if case .passed = result { session.end() }   // a pass ends the session
                isPresented = false
            }
        } else {
            checkBody
        }
    }

    @ViewBuilder
    private var checkBody: some View {
        switch store.settings.checkMethod {
        case .reaction:
            if let baseline = store.settings.reactionBaseline {
                ReactionCheckView(
                    title: "Check-in",
                    intro: "The screen will turn green at a random moment. Tap as fast as you can.",
                    totalTrials: ReactionRules.trialsPerRound,
                    onFinish: { result in
                        let verdict = ReactionRules.evaluate(result, baseline: baseline)
                        if case .failed = verdict { session.recordFailure() }
                        outcome = verdict
                    },
                    onCancel: { started in
                        if started { session.recordFailure() }   // backing out costs a try
                        isPresented = false
                    }
                )
            } else {
                unavailable
            }
        case .none:
            unavailable
        }
    }

    private var unavailable: some View {
        VStack(spacing: 16) {
            Text("No check-in is set up.")
            Button("Close") { isPresented = false }
        }
    }
}

struct CheckResultView: View {
    let outcome: CheckOutcome
    let retryMinutes: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            switch outcome {
            case .passed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text("Check-in passed")
                    .font(.title.bold())
                Text("Your reaction time was close to your usual. Your session will end now.")
                    .multilineTextAlignment(.center)
            case .failed(let reason):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                Text("Not this time")
                    .font(.title.bold())
                Text(reason)
                    .multilineTextAlignment(.center)
                Text("You can try again in \(retryMinutes) minutes.")
                    .multilineTextAlignment(.center)
            }

            Text(Disclaimer.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                onDone()
            } label: {
                Text(isPass ? "End session" : "Close")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var isPass: Bool {
        if case .passed = outcome { return true }
        return false
    }
}
