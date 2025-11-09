//
//  ShakeCatcherView.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 06.11.25.
//


import SwiftUI
internal import Combine

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

final class ShakeCatcherView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if bounds.size == .zero {
            frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        DispatchQueue.main.async { [weak self] in
            _ = self?.becomeFirstResponder()
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return false
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        NotificationCenter.default.post(name: .deviceDidShake, object: nil)
    }
}

struct ShakeDetector: UIViewRepresentable {
    func makeUIView(context: Context) -> ShakeCatcherView {
        let v = ShakeCatcherView(frame: .zero)
        return v
    }
    func updateUIView(_ uiView: ShakeCatcherView, context: Context) {}
}

final class ShakeManager {
    static let shared = ShakeManager()
    let publisher = NotificationCenter.default.publisher(for: .deviceDidShake)
    private init() {}
}
