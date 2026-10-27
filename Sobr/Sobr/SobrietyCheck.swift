import Foundation

/// Which kind of check-in the user picked in setup.
enum CheckMethod: String, Codable, CaseIterable, Identifiable {
    case none
    case reaction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None (timer only)"
        case .reaction: return "Reaction game"
        }
    }
}

/// Every check reports its result the same way.
enum CheckOutcome {
    case passed
    case failed(reason: String)
}

/// The user's normal reaction speed, recorded in setup.
struct ReactionBaseline: Codable, Equatable {
    var medianMs: Double
}

struct ReactionResult {
    let medianMs: Double
    let falseStarts: Int
}

enum ReactionRules {
    static let trialsPerRound = 5
    static let baselineRounds = 3
    static let passFactor = 1.25     // must be within 25% of the baseline
    static let maxFalseStarts = 2    // early taps allowed

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    static func evaluate(_ result: ReactionResult, baseline: ReactionBaseline) -> CheckOutcome {
        if result.falseStarts > maxFalseStarts {
            return .failed(reason: "Too many early taps.")
        }
        if result.medianMs <= baseline.medianMs * passFactor {
            return .passed
        }
        return .failed(reason: "Your reaction time was slower than usual.")
    }
}

enum Disclaimer {
    static let text = "This check-in is not a sobriety test and doesn't mean it's safe to drive. Never drive after drinking."
}
