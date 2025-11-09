//
//  Haptics.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import Foundation
import UIKit

enum Haptics {
    private static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }

    static func success() {
        guard isEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.warning)
    }

    static func error() {
        guard isEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.error)
    }

    static func light(_ intensity: CGFloat = 1.0) {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred(intensity: max(0.0, min(1.0, intensity)))
    }
    
    static func medium(_ intensity: CGFloat = 1.0) {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred(intensity: max(0.0, min(1.0, intensity)))
    }

    static func rigid(_ intensity: CGFloat = 1.0) {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred(intensity: max(0.0, min(1.0, intensity)))
    }

    static func selection() {
        guard isEnabled else { return }
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }
}
