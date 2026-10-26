//
//  FakeLiveEvent.swift
//  Riftbound Companiokay
//
//  Debug builds only (Android `DebugEvents`): a made-up live event answered here instead of by PlayRiftbound,
//  so match mode, Report and the event screens can be tried without a live event (Okay, 2026-10-26). The
//  Summoner Skirmish at "Spielwiese" has round 3 running with your table open; the stores, players and
//  results are fictional. Settings › Debug switches it; nothing is sent to Riot while it is on, a report or
//  a registration is only noted here. Every time in the answers moves by the moment the switch went on, so
//  the round clock runs as it would at the table. The answers come from tools/fake-live-event.
//

#if DEBUG
import Foundation

nonisolated enum FakeLiveEvent {
    private static let onKey = "debug.fakeLiveEvent"
    private static let sinceKey = "debug.fakeLiveEventSince"
    private static let appliedKey = "debug.fakeLiveEventApplied"

    static var isOn: Bool { UserDefaults.standard.bool(forKey: onKey) }

    /// On or off from a clean start: the times count from now and no report has been made yet.
    static func set(_ on: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(on, forKey: onKey)
        defaults.set(Date().timeIntervalSince1970, forKey: sinceKey)
        defaults.removeObject(forKey: appliedKey)
    }

    /// The signed-in player of the answers.
    static var credentials: PlayRiftboundCredentials {
        let session = files["session.json"].flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: String] }
        return PlayRiftboundCredentials(cookieHeader: "fake", expiry: nil, gameName: session?["gameName"], tagLine: session?["tagLine"])
    }

    /// What PlayRiftbound would answer to `request`: a mutation succeeds and changes the later answers, a
    /// query is looked up as `<operation>-<id>.json`, then `<operation>.json`; anything else is a 404.
    static func answer(to request: URLRequest, operation: String) -> (Data, Int) {
        if request.httpMethod == "POST" {
            var applied = UserDefaults.standard.stringArray(forKey: appliedKey) ?? []
            if !applied.contains(operation) { applied.append(operation) }
            UserDefaults.standard.set(applied, forKey: appliedKey)
            return (Data(#"{"data":{}}"#.utf8), 200)
        }
        let variables = request.url
            .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "variables" }?.value }
            .flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] }
        let id = ["tournamentId", "id", "organizerId"].lazy.compactMap { variables?[$0] as? String }.first
        let names = [id.map { "\(operation)-\($0).json" }, "\(operation).json"].compactMap { $0 }
        let applied = UserDefaults.standard.stringArray(forKey: appliedKey) ?? []
        for name in names {
            // The newest change first: after a report the event answers with the match reported.
            for change in applied.reversed() {
                if let text = files["after-\(change)/\(name)"] { return (Data(moved(text).utf8), 200) }
            }
            if let text = files[name] { return (Data(moved(text).utf8), 200) }
        }
        return (Data(), 404)
    }

    /// Every timestamp moved by the time between generating the answers and switching this on.
    private static func moved(_ text: String) -> String {
        let since = UserDefaults.standard.double(forKey: sinceKey)
        guard since > 0, let generated = files["_meta.json"].flatMap(generatedAt) else { return text }
        let shift = Date(timeIntervalSince1970: since).timeIntervalSince(generated)
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return text.replacing(#/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/#) { match in
            format.date(from: String(match.output)).map { format.string(from: $0.addingTimeInterval(shift)) } ?? String(match.output)
        }
    }

    private static func generatedAt(_ meta: String) -> Date? {
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let raw = (try? JSONSerialization.jsonObject(with: Data(meta.utf8)) as? [String: String])?["generatedAt"]
        return raw.flatMap(format.date(from:))
    }

    /// File name → answer, unpacked once from `packed` (FakeLiveEventData.swift).
    private static let files: [String: String] = {
        guard let blob = Data(base64Encoded: packed.filter { !$0.isWhitespace }),
              let json = try? (blob as NSData).decompressed(using: .zlib) as Data,
              let files = try? JSONSerialization.jsonObject(with: json) as? [String: String] else { return [:] }
        return files
    }()
}
#endif
