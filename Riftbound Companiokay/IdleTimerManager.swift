//
//  IdleTimerManager.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 02.11.25.
//

import SwiftUI
import UIKit
internal import Combine

@MainActor
final class IdleTimerManager: ObservableObject {
    @Published var isDisabled: Bool = true {
        didSet {
            UIApplication.shared.isIdleTimerDisabled = isDisabled
        }
    }

    init() {
        UIApplication.shared.isIdleTimerDisabled = isDisabled
    }
}

