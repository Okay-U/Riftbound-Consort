//
//  AddToCalendar.swift
//  Riftbound Companiokay
//
//  Lets the user add an event to their Apple Calendar. Uses the system
//  EKEventEditViewController so the user reviews and confirms before anything is
//  saved — we only ask for write-only calendar access (iOS 17+), never read.
//

import SwiftUI
import EventKit
import EventKitUI

/// The minimal event details we prefill into the calendar editor.
struct CalendarEventDraft: Identifiable {
    let id = UUID()
    let title: String
    let location: String?
    let start: Date
    let end: Date
}

/// SwiftUI wrapper around the system event editor. Present in a `.sheet`.
struct CalendarEditView: UIViewControllerRepresentable {
    let draft: CalendarEventDraft
    let store: EKEventStore
    var onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.location = draft.location
        event.startDate = draft.start
        event.endDate = draft.end
        event.calendar = store.defaultCalendarForNewEvents
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true)
            onFinish()
        }
    }
}
