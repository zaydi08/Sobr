import Foundation

enum LockMode: String, Codable, CaseIterable {
    case blockAllExcept   // everything is locked except the apps you choose
    case allowAllExcept   // only the apps you choose are locked
}

/// Someone the user trusts to contact when they feel unsafe.
struct SafetyContact: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var phoneNumber: String
}

struct SobrSettings: Codable {
    static let maxSafetyContacts = 3

    var mode: LockMode = .allowAllExcept
    var blockAllExceptApps: [String] = []   // apps that stay OPEN in "block all except"
    var allowAllExceptApps: [String] = []   // apps that get LOCKED in "allow all except"
    var soberUpMinutes: Int = 240
    var hasCompletedSetup: Bool = false
    var safetyContacts: [SafetyContact] = []
    var checkMethod: CheckMethod = .none
    var reactionBaseline: ReactionBaseline? = nil

    /// True when a check-in can actually be offered during a session.
    var checkIsReady: Bool {
        switch checkMethod {
        case .none: return false
        case .reaction: return reactionBaseline != nil
        }
    }

    /// True when the chosen method still needs its sober baseline.
    var needsBaseline: Bool {
        checkMethod == .reaction && reactionBaseline == nil
    }

    init() {}

    // Missing keys fall back to defaults, so older saved data still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = try c.decodeIfPresent(LockMode.self, forKey: .mode) ?? .allowAllExcept
        blockAllExceptApps = try c.decodeIfPresent([String].self, forKey: .blockAllExceptApps) ?? []
        allowAllExceptApps = try c.decodeIfPresent([String].self, forKey: .allowAllExceptApps) ?? []
        soberUpMinutes = try c.decodeIfPresent(Int.self, forKey: .soberUpMinutes) ?? 240
        hasCompletedSetup = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedSetup) ?? false
        safetyContacts = try c.decodeIfPresent([SafetyContact].self, forKey: .safetyContacts) ?? []
        checkMethod = try c.decodeIfPresent(CheckMethod.self, forKey: .checkMethod) ?? .none
        reactionBaseline = try c.decodeIfPresent(ReactionBaseline.self, forKey: .reactionBaseline)
    }
}
