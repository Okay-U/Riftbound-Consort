import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Cross-platform haptics facade. iOS uses UIKit feedback generators;
/// Android is a logged stub for the spike (Vibrator mapping is a follow-up).
enum Haptics {
    private static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }

    static func warning() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.warning)
        #else
        logger.debug("haptic: warning")
        #endif
    }

    static func medium(_ intensity: Double = 1.0) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred(intensity: max(0.0, min(1.0, intensity)))
        #else
        logger.debug("haptic: medium \(intensity)")
        #endif
    }

    static func light(_ intensity: Double = 1.0) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred(intensity: max(0.0, min(1.0, intensity)))
        #else
        logger.debug("haptic: light \(intensity)")
        #endif
    }

    static func rigid(_ intensity: Double = 1.0) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred(intensity: max(0.0, min(1.0, intensity)))
        #else
        logger.debug("haptic: rigid \(intensity)")
        #endif
    }

    static func selection() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
        #else
        logger.debug("haptic: selection")
        #endif
    }
}
