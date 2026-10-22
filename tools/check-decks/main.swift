import Foundation

// The Android unit tests of the same rules (DeckRulesTest), case by case, on the Android test fixture.

let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as! [String: Any]
let items = raw["items"] as! [[String: Any]]

func decode(_ json: [String: Any]) -> Card {
    try! JSONDecoder().decode(Card.self, from: JSONSerialization.data(withJSONObject: json))
}

let all = items.map(decode)
let cards = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
func named(_ name: String) -> Card { all.first { $0.name == name }! }
func json(_ name: String) -> [String: Any] { items.first { ($0["name"] as? String) == name }! }

var checks = 0
func check(_ ok: Bool, _ what: String, line: Int = #line) {
    checks += 1
    if !ok {
        print("FAIL line \(line): \(what)")
        exit(1)
    }
}

let t1 = Date(timeIntervalSince1970: 1)
let t2 = Date(timeIntervalSince1970: 2)
func empty() -> Decklist {
    var d = Decklist(name: "Test")
    d.createdAt = Date(timeIntervalSince1970: 0)
    d.updatedAt = Date(timeIntervalSince1970: 0)
    return d
}
extension Decklist {
    func with(_ card: Card, _ times: Int = 1, pool: [String: Card] = cards) -> Decklist {
        (0..<times).reduce(self) { d, _ in DeckRules.add(card, to: d, cards: pool, at: t1) }
    }
}

let darius = named("Darius - Hand of Noxus")
let trifarian = named("Darius - Trifarian")
let trifarianAlt = named("Darius - Trifarian (Alternate Art)")
let executioner = named("Darius - Executioner")
let kinkou = named("Kinkou Monk")
let furyRune = cards["ogn-007-298"]!

// Printings of a card share one identity.
check(DeckRules.identityKey(trifarian) == "name:darius trifarian", "identity key")
check(DeckRules.identityKey(trifarian) == DeckRules.identityKey(trifarianAlt), "printings share it")

// A champion fills the chosen slot first, then the main deck, three copies in all.
do {
    var d = empty().with(darius).with(trifarian)
    check(d.legend?.cardId == darius.id, "legend")
    check(d.champion?.cardId == trifarian.id, "chosen champion")
    d = d.with(trifarianAlt).with(trifarian)
    check(DeckRules.total(d.mainDeck) == 2, "then the main deck")
    check(DeckRules.copies(of: trifarianAlt, in: d, cards: cards) == 3, "copies across printings")
    check(DeckRules.blocker(trifarianAlt, in: d, cards: cards) == "3 copies already", "copy limit")
}

// The legend's domains decide what fits, colourless always does, tokens never.
do {
    let d = empty().with(darius)
    check(DeckRules.blocker(kinkou, in: d, cards: cards) == "Outside the legend's domains", "outside")
    check(DeckRules.blocker(executioner, in: d, cards: cards) == nil, "inside")
    check(DeckRules.blocker(kinkou, in: empty(), cards: cards) == nil, "no legend yet")
    var ballista = json("Iron Ballista")
    ballista["classification"] = ["type": "Gear", "domain": ["Colorless"]]
    check(DeckRules.eligible(decode(ballista), legendDomains: ["fury", "order"]), "colourless fits")
    check(!DeckRules.eligible(named("Buff"), legendDomains: ["fury", "order"]), "token never")
}

// Battlefields, runes, signatures and the main deck have their limits.
do {
    let fields = all.filter(\.isBattlefield)
    var d = fields.reduce(empty()) { $0.with($1) }
    check(d.battlefields.count == 3, "three battlefields")
    check(DeckRules.blocker(fields[0], in: d, cards: cards) == "Already a battlefield", "one each")
    d = d.with(furyRune, 12)
    check(d.runes.count == 1 && d.runes[0].count == 12, "twelve runes")
    check(DeckRules.blocker(furyRune, in: d, cards: cards) == "12 runes already", "rune limit")

    // No clean name: "Other" below must be a card of its own, not a copy of this one.
    var signature = json("Blazing Scorcher")
    signature["id"] = "sig"
    signature["metadata"] = nil
    var classification = signature["classification"] as! [String: Any]
    classification["supertype"] = "Signature"
    signature["classification"] = classification
    var other = signature
    other["id"] = "other"
    other["name"] = "Other"
    var pool = cards
    pool["sig"] = decode(signature)
    pool["other"] = decode(other)
    var signed = empty()
    signed.mainDeck = [DecklistEntry(cardId: "other", cardName: "Other", count: 3)]
    check(DeckRules.blocker(decode(signature), in: signed, cards: pool) == "3 signature cards already", "signature limit")

    var full = empty()
    full.mainDeck = [DecklistEntry(cardId: "filler", cardName: "Filler", count: 39)]
    check(DeckRules.blocker(named("Cleave"), in: full, cards: cards) == "Main deck is full", "main deck full")
}

// The legend's champion tag decides champions and signature cards, not a shared tag.
do {
    func card(_ name: String, _ type: String, _ supertype: String?, _ tags: [String]) -> Card {
        var c: [String: Any] = ["id": name, "name": name, "tags": tags]
        c["classification"] = supertype.map { ["type": type, "supertype": $0] } ?? ["type": type]
        return decode(c)
    }
    let kennen = card("Kennen - Heart of the Tempest", "Legend", nil, ["Yordle", "Kennen"])
    check(card("Kennen - Thunder", "Unit", "Champion", ["Yordle", "Kennen"]).matchesLegend(kennen), "own champion")
    // Teemo is a Yordle too, but not Kennen.
    check(!card("Teemo - Scout", "Unit", "Champion", ["Yordle", "Teemo"]).matchesLegend(kennen), "shared tag is not it")
    let own = card("Lightning Rush - Kennen", "Spell", "Signature", ["Kennen"])
    let jinxs = card("Super Mega Death Rocket! - Jinx", "Spell", "Signature", ["Jinx"])
    check(own.signatureFits(legend: kennen) && !jinxs.signatureFits(legend: kennen) && jinxs.signatureFits(legend: nil), "signature fits")
    // The signed printing of a legend is not a Signature card.
    let signedLegend = decode(["id": "k2", "name": "Kennen - Heart of the Tempest (Signature)", "classification": ["type": "Legend"], "metadata": ["signature": true]])
    check(!signedLegend.isSignature, "signed printing")
}

// A sideboard holds up to ten cards.
do {
    func side(_ n: Int) -> Decklist {
        var d = empty()
        d.sideDeck = n == 0 ? [] : [DecklistEntry(cardId: "s", cardName: "S", count: n)]
        return d
    }
    check(!DeckRules.issues(side(8)).contains { $0.hasPrefix("Side deck") }, "8 fine")
    check(!DeckRules.issues(side(10)).contains { $0.hasPrefix("Side deck") }, "10 fine")
    check(DeckRules.issues(side(11)).contains("Side deck: 11 (max 10)"), "11 too many")
}

// Remove takes main deck copies before the chosen champion.
do {
    var d = empty().with(darius).with(trifarian, 2)
    check(DeckRules.count(trifarian, in: d) == 2, "count all slots")
    d = DeckRules.remove(trifarian, from: d, at: t2)
    check(d.mainDeck.isEmpty && d.champion?.cardId == trifarian.id, "main deck first")
    check(d.updatedAt == t2, "edit time")
    check(DeckRules.remove(kinkou, from: d, at: Date(timeIntervalSince1970: 3)) == d, "not in the deck")
}

// Issues use the classic wording.
do {
    check(DeckRules.issues(empty()) == ["Missing champion", "Missing legend", "Battlefields: 0/3", "Main deck: 0/39", "Runes: 0/12"], "empty deck")
    var wrong = empty().with(darius)
    wrong.mainDeck = [DecklistEntry(cardId: kinkou.id, cardName: kinkou.name, count: 4)]
    let issues = DeckRules.issues(wrong, cards: cards)
    check(issues.contains("Kinkou Monk: 4 copies (max 3)") && issues.contains("Kinkou Monk: outside Darius's domains"), "\(issues)")
}

// The match log's numbers (Redesign/Decks/MatchLog.swift).
do {
    func ev(_ s: Int, _ slot: Int, _ type: ScoreEventType, _ delta: Int) -> ScoreEvent {
        ScoreEvent(elapsedSeconds: s, slot: slot, type: type, delta: delta)
    }
    let game = GameRecord(result: .won, durationSeconds: 750, events: [
        ev(30, Seat.opponent, .manual, -1), ev(10, Seat.you, .conquer, 1), ev(20, Seat.you, .hold, 1),
        ev(40, Seat.you, .manual, -1), ev(50, Seat.opponent, .manual, 2),
    ], startedFirst: true)
    let points = MatchLog.points(game)
    check(points.map(\.seconds) == [10, 20, 30, 40, 50], "in time order")
    check(points[2].them == 0, "a fix never goes below 0")
    check(MatchLog.score(game).map { $0.you == 1 && $0.them == 2 } == true, "final score")
    let race = MatchLog.race(game)
    check(race[Seat.you] == [.conquer] && race[Seat.opponent] == [.manual, .manual], "a fix takes the last point back")
    let four = GameRecord(result: .lost, durationSeconds: 90, events: [ev(5, 2, .conquer, 1)])
    check(MatchLog.points(four).isEmpty && MatchLog.score(four) == nil, "4 players have no race")
    let lostFirst = GameRecord(result: .lost, durationSeconds: 810, startedFirst: true)
    let wonSecond = GameRecord(result: .won, durationSeconds: 60, startedFirst: false)
    let split = MatchLog.firstSecond([game, lostFirst, wonSecond, four])
    check(split.first == Tally(wins: 1, losses: 1) && split.second == Tally(wins: 1, losses: 0), "first / second")
    check(MatchLog.averageMinutes([game, lostFirst]) == 13 && MatchLog.averageMinutes([four]) == 2 && MatchLog.averageMinutes([]) == nil, "average")
    check(Tally.of([game, lostFirst, wonSecond]).percent == "67%" && Tally.of([]).percent == "–", "percent")
    check(MatchLog.opponentShort("Darius - Hand of Noxus") == "Darius" && MatchLog.opponentShort("") == "Unknown", "short name")
}

print("deck rules ok (\(checks) checks)")
