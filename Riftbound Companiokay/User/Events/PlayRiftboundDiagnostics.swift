//
//  PlayRiftboundDiagnostics.swift
//  Riftbound Companiokay
//
//  A small on-device log of PlayRiftbound API calls (operation, outcome, Riot's
//  error messages, timing) so a live-event test can be read afterwards from
//  Settings without a Mac attached. Never records cookies, headers or
//  responses; mutation variables (tournament, game and participant ids) are
//  kept because they are what a failed report needs explaining.
//

import Foundation
import SwiftUI

nonisolated struct PlayRiftboundLogEntry: Codable, Sendable, Identifiable {
    let id: UUID
    let date: Date
    let operation: String
    let method: String
    let outcome: String
    let detail: String?
    let durationMs: Int

    var line: String {
        let stamp = date.formatted(.dateTime.day().month(.abbreviated).hour().minute().second())
        return "\(stamp) \(method) \(operation) → \(outcome) (\(durationMs) ms)" + (detail.map { "\n    \($0)" } ?? "")
    }
}

actor PlayRiftboundDiagnostics {
    static let shared = PlayRiftboundDiagnostics()
    private static let limit = 150
    private static let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("playriftbound_log.json")

    private var entries: [PlayRiftboundLogEntry] = []
    private var loaded = false

    func record(operation: String, method: String, outcome: String, detail: String? = nil, started: Date) {
        load()
        let entry = PlayRiftboundLogEntry(id: UUID(), date: Date(), operation: operation, method: method, outcome: outcome,
                                          detail: detail.map { String($0.prefix(600)) },
                                          durationMs: Int(Date().timeIntervalSince(started) * 1000))
        entries.append(entry)
        if entries.count > Self.limit { entries.removeFirst(entries.count - Self.limit) }
        save()
    }

    func all() -> [PlayRiftboundLogEntry] {
        load()
        return entries.reversed()
    }

    func clear() {
        entries = []
        save()
    }

    func exportText() -> String {
        load()
        let header = "Riftcount PlayRiftbound log · \(entries.count) entries · app \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")"
        return ([header] + entries.reversed().map(\.line)).joined(separator: "\n")
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([PlayRiftboundLogEntry].self, from: data) {
            entries = saved
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}

// MARK: - Settings screen

struct PlayRiftboundLogView: View {
    @State private var entries: [PlayRiftboundLogEntry] = []
    @State private var exportText = ""

    var body: some View {
        List {
            if entries.isEmpty {
                Text("No PlayRiftbound calls logged yet.").foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(entry.operation).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(entry.outcome)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(entry.outcome == "ok" ? .green : .red)
                    }
                    Text("\(entry.method) · \(entry.durationMs) ms · \(entry.date.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                    if let detail = entry.detail {
                        Text(detail).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("PlayRiftbound log")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: exportText) { Image(systemName: "square.and.arrow.up") }
                    .disabled(entries.isEmpty)
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Clear", role: .destructive) { Task { await PlayRiftboundDiagnostics.shared.clear(); await reload() } }
                    .disabled(entries.isEmpty)
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        entries = await PlayRiftboundDiagnostics.shared.all()
        exportText = await PlayRiftboundDiagnostics.shared.exportText()
    }
}
