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

/// SplitMix64: a seeded shuffle for the hand checks.
struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

func entry(_ id: String, _ name: String, _ count: Int) -> DecklistEntry { DecklistEntry(cardId: id, cardName: name, count: count) }

// Draw odds, stats and the test hand (Android DeckMathTest).
do {
    check(abs(Odds.atLeast(deck: 39, copies: 3, drawn: 4, k: 1) - 0.2838) < 0.0001, "a 3-of in 4 cards")
    check(abs(Odds.atLeast(deck: 39, copies: 39, drawn: 4, k: 1) - 1) < 1e-9, "every card")
    check(Odds.atLeast(deck: 39, copies: 1, drawn: 4, k: 2) == 0, "more than there are")
    check(Odds.binomial(5, 2) == 10, "binomial")

    var deck = empty()
    deck.champion = entry("ogn-027-298", "Darius - Trifarian", 1)
    deck.mainDeck = [entry("ogn-004-298", "Cleave", 3), entry("ogn-011-298", "Magma Wurm", 1)]
    deck.sideDeck = [entry("ogn-008-298", "Get Excited!", 2)]
    let s = DeckStats.of(deck, cards: cards)
    check(s.curve[1] == 3 && s.curve[5] == 1 && s.curve[7] == 1, "curve \(s.curve)")
    check(s.types == [.init(name: "Unit", count: 2), .init(name: "Spell", count: 3), .init(name: "Gear", count: 0)], "types \(s.types)")
    check(abs((s.averageEnergy ?? 0) - Double(3 * 1 + 5 + 8) / 5) < 1e-9, "average")
    check(s.power.count == 1 && s.power[0].name == "Fury", "power \(s.power)")

    var ten = empty()
    ten.mainDeck = (1...10).map { entry("c\($0)", "C\($0)", 1) }
    var random = SeededRandom(seed: 3)
    var h = Hand.deal(ten, using: &random)
    check(h.cards.count == 4 && h.pile.count == 6, "opening hand")
    let first = h.cards[0]
    h = h.toggle(first.id).hand.toggle(h.cards[1].id).hand
    check(h.toggle(h.cards[2].id).note == "Mulligan up to 2 cards", "two at most")
    let before = h.pile
    h = h.mulligan()
    check(h.mulliganUsed, "used")
    check(Array(h.pile.dropLast()) == Array(before.dropFirst(2)) + [first.cardId], "to the bottom")
    check(h.toggle(h.cards[0].id).note == "One mulligan per game", "once")
    for _ in 0..<10 { h = h.draw() }
    check(h.cards.count == Hand.max, "eight at most")
    var random2 = SeededRandom(seed: 4)
    let next = Hand.deal(ten, firstId: 4, using: &random2)
    check(next.cards.map(\.id) == [4, 5, 6, 7] && next.nextId == 8, "a new hand has new ids")
}

// The deck screen's edits (Android DeckEditsTest).
do {
    var base = empty()
    base.legend = entry("ogn-253-298", "Darius - Hand of Noxus", 1)
    base.champion = entry("ogn-027-298", "Darius - Trifarian", 1)
    base.mainDeck = [entry("ogn-243-298", "Darius - Executioner", 2)]
    base.runes = [entry("ogn-007a-298", "Fury Rune (Alternate Art)", 5)]
    let executioner = named("Darius - Executioner")
    let swapped = DeckEdits.champion(base, executioner, at: t1)
    check(swapped.champion?.cardId == "ogn-243-298", "new champion")
    check(swapped.mainDeck.map { "\($0.cardId):\($0.count)" } == ["ogn-243-298:1", "ogn-027-298:1"], "the old one takes its place")
    var sideOnly = base
    sideOnly.sideDeck = base.mainDeck
    sideOnly.mainDeck = []
    let fromSide = DeckEdits.champion(sideOnly, executioner, at: t1)
    check(fromSide.mainDeck.isEmpty && DeckRules.total(fromSide.sideDeck) == 2, "from the side")
    check(DeckEdits.runeCount(base, domain: "Fury", cards: cards) == 5, "runes across printings")
    let fields = all.filter { $0.isBattlefield }
    var d = base
    for field in fields { d = DeckEdits.toggleBattlefield(d, field, at: t1) ?? d }
    var full = d
    full.battlefields = Array(d.battlefields.dropLast()) + [entry("x", "X", 1)]
    check(d.battlefields.count == 3 && DeckEdits.toggleBattlefield(full, fields[fields.count - 1], at: t1) == nil, "three at most")
}

// The builder's draft (Android BuilderTest).
do {
    let darius = named("Darius - Hand of Noxus")
    let trifarian = named("Darius - Trifarian")
    let trifarianAlt = named("Darius - Trifarian (Alternate Art)")
    var start = Draft()
    start.main = [entry("x", "X", 3)]
    let d = Builder.pickLegend(start, darius)
    check(d.main.isEmpty && d.name == "Darius deck" && d.runes == ["fury": 6, "order": 6], "a legend resets the draft")
    check(Builder.evenSplit(["A", "B", "C"]) == ["a": 4, "b": 4, "c": 4], "even split")
    var mine = d
    mine.name = "Mine"
    check(Builder.pickLegend(mine, darius).name == "Mine", "the same legend keeps the name")

    let inPool = Builder.pool(d, all)
    check(inPool.allSatisfy { $0.domains.allSatisfy { ["Fury", "Order", "Colorless"].contains($0) } }, "the legend's domains")
    check(!inPool.contains { $0.isLegend || $0.isRune || $0.isBattlefield || $0.isToken }, "no legends, runes, battlefields or tokens")
    check(inPool.firstIndex { $0.domains == ["Fury"] } == 0, "the cheapest Fury card first")
    check(Set(Builder.champions(legend: darius, pool: all).map(\.id)).isSuperset(of: ["ogn-027-298", "ogn-243-298"]), "champions")
    check(!Builder.legends(all).contains { $0.name.hasSuffix("(Signature)") }, "no signature legends")

    var c = Builder.pickChampion(Builder.pickLegend(Draft(), darius), trifarian)
    c = Builder.add(c, .main, trifarian)
    c = Builder.add(c, .side, trifarianAlt)
    check(Builder.copies(c, trifarian, cards: cards) == 3, "copies across printings and the champion")
    check(Builder.blocker(c, .main, trifarianAlt, cards: cards) == "3 copies already", "the fourth copy")
    c = Builder.remove(c, .side, trifarianAlt)
    check(Builder.blocker(c, .main, trifarianAlt, cards: cards) == nil, "room again")
    check(Builder.rune(c, "fury", 1).runeCount == 12 && Builder.rune(c, "fury", -1).runes["fury"] == 5, "rune steps")

    let pool = Builder.pickLegend(Draft(), darius)
    check(Builder.rune(pool, "fury", -1).runes == ["fury": 5, "order": 7], "one down is the other up")
    check(Builder.rune(pool, "order", 1).runes == ["fury": 5, "order": 7], "one up is the other down")
    var short = pool
    short.runes = ["fury": 4, "order": 4]
    check(Builder.rune(short, "fury", 1).runes == ["fury": 5, "order": 4] && Builder.rune(short, "fury", -1).runes == ["fury": 3, "order": 4], "a short pool")
    var edge = pool
    edge.runes = ["fury": 12, "order": 0]
    check(Builder.rune(edge, "fury", 1).runes == edge.runes && Builder.rune(edge, "order", -1).runes == edge.runes, "the edges")
    check(Builder.rune(edge, "fury", -1).runes == ["fury": 11, "order": 1], "off the edge")

    var s = Builder.pickChampion(Builder.pickLegend(Draft(), darius), trifarian)
    for field in all where field.isBattlefield { s = Builder.toggleBattlefield(s, field) }
    s = Builder.add(s, .main, named("Cleave"))
    let saved = Builder.toDeck(s, pool: all, at: t1)
    check(saved.runes.map { "\($0.cardId):\($0.count)" } == ["rad-r01:6"], "only the Fury half has a rune card")
    check(saved.battlefields.count == 3 && saved.createdAt == t1, "three fields")
    let again = Builder.fromDeck(saved, cards: cards)
    check(again.legend == s.legend && again.champion == s.champion && again.battlefields == s.battlefields && again.main == s.main && again.name == s.name, "round trip")
    check(again.runes == ["fury": 6, "order": 0], "runes back")
    let resaved = Builder.toDeck(again, pool: all, at: t2)
    check(resaved.id == saved.id && resaved.createdAt == saved.createdAt, "the same deck")

    var legacy = empty()
    legacy.legend = entry("legacy-legend", "Old Legend", 1)
    legacy.battlefields = [entry("legacy-bf", "Old Field", 1)]
    legacy.runes = [entry("legacy-rune", "Old Rune", 12)]
    let kept = Builder.fromDeck(legacy, cards: cards)
    check(kept.keepBattlefields && kept.keepRunes, "kept as they are")
    let back = Builder.toDeck(kept, pool: all, at: t1)
    check(back.legend == legacy.legend && back.battlefields == legacy.battlefields && back.runes == legacy.runes, "unchanged")
}

print("deck rules ok (\(checks) checks)")
