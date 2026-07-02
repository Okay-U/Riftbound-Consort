import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// Cross-platform haptics.
/// iOS: UIKit feedback generators, called imperatively.
/// Android: UIFeedbackGenerator shims are transpiled-mode only, so haptic
/// events bump counters on this engine and the root view maps them to
/// `.sensoryFeedback` modifiers (SkipUI bridges those to the Vibrator;
/// VIBRATE permission is set in AndroidManifest.xml).
@Observable @MainActor public final class HapticsEngine {
    public static let shared = HapticsEngine()
    private init() {}

    var impactCount = 0
    var selectionCount = 0
    var warningCount = 0
    var successCount = 0
}

@MainActor
enum Haptics {
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    static func success() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
        #else
        HapticsEngine.shared.successCount += 1
        #endif
    }

    static func warning() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.warning)
        #else
        HapticsEngine.shared.warningCount += 1
        #endif
    }

    static func medium(_ intensity: Double = 1.0) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred(intensity: max(0.0, min(1.0, intensity)))
        #else
        HapticsEngine.shared.impactCount += 1
        #endif
    }

    static func light(_ intensity: Double = 1.0) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred(intensity: max(0.0, min(1.0, intensity)))
        #else
        HapticsEngine.shared.impactCount += 1
        #endif
    }

    static func rigid(_ intensity: Double = 1.0) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred(intensity: max(0.0, min(1.0, intensity)))
        #else
        HapticsEngine.shared.impactCount += 1
        #endif
    }

    static func selection() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
        #else
        HapticsEngine.shared.selectionCount += 1
        #endif
    }
}
