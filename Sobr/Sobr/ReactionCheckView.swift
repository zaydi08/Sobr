import SwiftUI
import QuartzCore

struct ReactionCheckView: View {
    let title: String
    let intro: String
    let totalTrials: Int
    let onFinish: (ReactionResult) -> Void
    let onCancel: (_ startedTrials: Bool) -> Void

    private enum Phase {
        case intro
        case waiting
        case ready
        case tooEarly
        case shown(Double)
    }

    @State private var phase: Phase = .intro
    @State private var times: [Double] = []
    @State private var falseStarts = 0
    @State private var readyAt: CFTimeInterval = 0
    @State private var touchHandled = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if case .intro = phase {
                    introView
                } else {
                    trialView
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        task?.cancel()
                        onCancel(hasStarted)
                    }
                }
            }
        }
        .onDisappear { task?.cancel() }
    }

    // MARK: - Screens

    private var introView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bolt.fill")
                .font(.system(size: 48))
            Text(intro)
                .multilineTextAlignment(.center)
            Text("\(totalTrials) quick taps. Don't tap before the screen turns green.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                startTrial()
            } label: {
                Text("Start")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    private var trialView: some View {
        ZStack {
            backgroundColor
            VStack(spacing: 12) {
                Text(progressText)
                    .font(.subheadline)
                Text(headline)
                    .font(.system(size: 44, weight: .bold))
                Text(subline)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding()
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in touchDown() }
                .onEnded { _ in touchHandled = false }
        )
    }

    // MARK: - Display values

    private var backgroundColor: Color {
        switch phase {
        case .intro: return .clear
        case .waiting: return .red
        case .ready: return .green
        case .tooEarly: return .orange
        case .shown: return .blue
        }
    }

    private var headline: String {
        switch phase {
        case .intro: return ""
        case .waiting: return "Wait…"
        case .ready: return "TAP!"
        case .tooEarly: return "Too early"
        case .shown(let ms): return "\(Int(ms.rounded())) ms"
        }
    }

    private var subline: String {
        switch phase {
        case .waiting: return "Tap when the screen turns green"
        case .tooEarly: return "Wait for green. Restarting…"
        default: return ""
        }
    }

    private var progressText: String {
        var current = times.count
        if case .shown = phase { } else { current += 1 }
        current = min(max(current, 1), totalTrials)

        let perRound = ReactionRules.trialsPerRound
        if totalTrials > perRound {
            let round = (current - 1) / perRound + 1
            let trial = (current - 1) % perRound + 1
            return "Round \(round) of \(totalTrials / perRound) · Trial \(trial) of \(perRound)"
        }
        return "Trial \(current) of \(totalTrials)"
    }

    private var hasStarted: Bool {
        if case .intro = phase { return false }
        return true
    }

    // MARK: - Logic

    private func touchDown() {
        guard !touchHandled else { return }
        touchHandled = true

        switch phase {
        case .waiting:
            // Tapped before green: doesn't count as a trial, restart it.
            falseStarts += 1
            phase = .tooEarly
            schedule(after: 1.0) { startTrial() }
        case .ready:
            let ms = (CACurrentMediaTime() - readyAt) * 1000
            times.append(ms)
            phase = .shown(ms)
            schedule(after: 1.0) { nextOrFinish() }
        default:
            break
        }
    }

    private func startTrial() {
        phase = .waiting
        let delay = Double.random(in: 1.5...4.0)
        schedule(after: delay) {
            readyAt = CACurrentMediaTime()
            phase = .ready
        }
    }

    private func nextOrFinish() {
        if times.count >= totalTrials {
            onFinish(ReactionResult(medianMs: ReactionRules.median(times),
                                    falseStarts: falseStarts))
        } else {
            startTrial()
        }
    }

    private func schedule(after seconds: Double, _ action: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            action()
        }
    }
}
