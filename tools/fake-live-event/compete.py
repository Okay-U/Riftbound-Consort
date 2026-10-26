# compete.py <sample.json> <outdir> : PlayRiftbound answers for the debug "Fake live event" switch (Android
# DebugEvents, iOS FakeLiveEvent). Turns the Events mocks' fictional Stuttgart data into Compete GraphQL responses,
# timed around now: e1 is live with round 3 running and your table open. Run through build.sh.
import json, os, sys, random
from datetime import datetime, timedelta, timezone

src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
os.makedirs(out, exist_ok=True)
random.seed(7)
BERLIN = timezone(timedelta(hours=2))
now = datetime.now(timezone.utc)
MOCK_TODAY = datetime(2026, 10, 21, tzinfo=BERLIN)
today = now.astimezone(BERLIN).replace(hour=0, minute=0, second=0, microsecond=0)
MON = {"SEP": 9, "OCT": 10, "NOV": 11}

def when(e):
    h, m = map(int, e["time"].split(":"))
    mock = datetime(2026, MON[e["mon"]], e["day"], h, m, tzinfo=BERLIN)
    return today + (mock - MOCK_TODAY)

def iso(t): return t.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

ME = {"id": "p0", "displayName": "Okay", "tagLine": "EUW"}
def player(pid):
    if pid == 0: return ME
    p = d["players"][pid]
    return {"id": f"p{pid}", "displayName": p["name"], "tagLine": "EUW"}

STUTTGART = (48.7758, 9.1829)
def organizer(sid, full=False):
    s = next(x for x in d["stores"] if x["id"] == sid)
    lat, lng = STUTTGART[0] + s["km"] / 111.0 * 0.6, STUTTGART[1] + s["km"] / 74.0 * 0.6
    o = {"id": sid, "name": s["name"], "isFavorited": s["fav"], "physicalAddress": {"city": s["city"], "adminArea1": "BW", "formattedAddress": s["addr"], "latitude": lat, "longitude": lng}}
    return o

FMT = {"Constructed": "CONSTRUCTED", "Sealed": "LIMITED_SEALED", "Draft": "LIMITED_DRAFT", "Casual": "CASUAL", "Starter decks": "STARTER"}
PROG = {"Summoner Skirmish": "SUMMONER_SKIRMISH", "Nexus Night": "NEXUS_NIGHT", "Open Play": "OPEN_PLAY", "Pre-Rift": "PRE_RIFT", "Learn to Play": "LEARN_TO_PLAY"}
def fee(e):
    p = e["price"]
    return None if p == "Free" else {"currency": "EUR", "minorUnits": int(float(p.strip("€")) * 100)}
def summary(e):
    parts = e["fmt"].split(" • ")
    return {"id": e["id"], "name": e["name"], "startsAt": iso(when(e)), "pricing": "FREE" if e["price"] == "Free" else "PAID", "entryFee": fee(e),
            "registrantCounts": [{"status": "REGISTERED", "count": e["players"]}],
            "config": {"tournamentType": PROG[e["program"]], "format": FMT.get(parts[0], "CONSTRUCTED"), "playerFormat": "TWO_V_TWO" if "2v2" in e["fmt"] else "ONE_V_ONE", "participantCapacity": e["cap"]}}
def entry(e): return {"organizer": organizer(e["store"]), "tournament": summary(e)}

def team(pid): return {"esportsTeamId": f"T{pid}", "players": [player(pid)]}

def games_for(mid, a, b, res, best_of=3):
    """Games with per-game outcomes; res None = still open."""
    games = []
    if res is None:
        return [{"esportsGameId": f"{mid}-g{i}", "number": i, "teamOutcomes": []} for i in range(1, best_of + 1)]
    seq = []
    if res["w"] == -1:
        seq = ["a", "b", "d"][: res["a"] + res["b"] + 1]
    else:
        wa, wb = res["a"], res["b"]
        seq = ["a"] * wa + ["b"] * wb
        win = "a" if res["w"] == a else "b"
        # the winner takes the last game
        seq.sort(key=lambda s: 1 if s == win else 0)
    for i, s in enumerate(seq, 1):
        if s == "d":
            outs = [{"esportsTeamId": f"T{a}", "outcome": "DRAW"}, {"esportsTeamId": f"T{b}", "outcome": "DRAW"}]
        else:
            wid, lid = (a, b) if s == "a" else (b, a)
            outs = [{"esportsTeamId": f"T{wid}", "outcome": "WIN"}, {"esportsTeamId": f"T{lid}", "outcome": "LOSS"}]
        games.append({"esportsGameId": f"{mid}-g{i}", "number": i, "teamOutcomes": outs})
    for i in range(len(seq) + 1, best_of + 1):
        games.append({"esportsGameId": f"{mid}-g{i}", "number": i, "teamOutcomes": []})
    return games

def match(mid, table, a, b, res, best_of=3):
    if res is None:
        outs = []
    elif res["w"] == -1:
        outs = [{"esportsTeamId": f"T{a}", "outcome": "DRAW"}, {"esportsTeamId": f"T{b}", "outcome": "DRAW"}]
    else:
        lo = b if res["w"] == a else a
        outs = [{"esportsTeamId": f"T{res['w']}", "outcome": "WIN"}, {"esportsTeamId": f"T{lo}", "outcome": "LOSS"}]
    return {"esportsMatchId": mid, "tableNumber": table, "status": "IN_PROGRESS", "config": {"count": best_of},
            "teams": [team(a), team(b)], "teamOutcomes": outs, "games": games_for(mid, a, b, res, best_of)}

def standings(rounds, upto, ids):
    """Riot's rules (CompeteStandings) for the official end-of-round tables."""
    pts = {i: 0 for i in ids}; byep = {i: 0 for i in ids}; w = {i: 0 for i in ids}; l = {i: 0 for i in ids}; dr = {i: 0 for i in ids}
    played = {i: 0 for i in ids}; gw = {i: 0 for i in ids}; gl = {i: 0 for i in ids}; opp = {i: [] for i in ids}
    for r in rounds:
        if r["n"] > upto: continue
        if r.get("bye") is not None:
            b = r["bye"]; pts[b] += 3; byep[b] += 3; w[b] += 1
        for t in r["tables"]:
            res = t["res"]
            if not res: continue
            a, b = t["a"], t["b"]
            opp[a].append(b); opp[b].append(a); played[a] += 1; played[b] += 1
            if res["w"] == -1:
                pts[a] += 1; pts[b] += 1; dr[a] += 1; dr[b] += 1
            else:
                lo = b if res["w"] == a else a
                pts[res["w"]] += 3; w[res["w"]] += 1; l[lo] += 1
            gw[a] += res["a"]; gl[a] += res["b"]; gw[b] += res["b"]; gl[b] += res["a"]
    mw = lambda i: max(0.33, (pts[i] - byep[i]) / (3 * played[i])) if played[i] else 0.33
    gwp = lambda i: max(0.33, gw[i] / (gw[i] + gl[i])) if gw[i] + gl[i] else 0.33
    mean = lambda xs, f: sum(f(x) for x in xs) / len(xs) if xs else 0.33
    rows = [{"id": i, "pts": pts[i], "omw": mean(opp[i], mw), "gw": gwp(i), "ogw": mean(opp[i], gwp)} for i in ids]
    rows.sort(key=lambda r: (-r["pts"], -round(r["omw"], 9), -round(r["gw"], 9), -round(r["ogw"], 9), r["id"]))
    return [{"esportsTeamId": f"T{r['id']}", "rank": k + 1, "matchPoints": r["pts"], "matchWins": w[r["id"]], "matchLosses": l[r["id"]], "matchDraws": dr[r["id"]],
             "matchWinPercentage": mw(r["id"]), "opponentMatchWinPercentage": r["omw"], "gameWinPercentage": r["gw"], "opponentGameWinPercentage": r["ogw"]} for k, r in enumerate(rows)]

def tournament(e, stages=None, participants=None, registrants=None, round_count=None, structure="SWISS", desc=None):
    s = summary(e)
    t = {"id": e["id"], "name": e["name"], "description": desc or "Bring your own sleeves. Pairings and results run on PlayRiftbound.",
         "tournamentProgram": {"id": "prog", "programName": e["program"]}, "startsAt": s["startsAt"], "endsAt": iso(when(e) + timedelta(hours=5)),
         "registrationEndAt": iso(when(e)), "pricing": s["pricing"], "entryFee": s["entryFee"], "registrantCounts": s["registrantCounts"],
         "config": {"tournamentType": s["config"]["tournamentType"], "format": s["config"]["format"], "playerFormat": s["config"]["playerFormat"],
                    "structure": structure, "matchFormat": "BEST_OF_THREE" if "three" in e["meta"] else "BEST_OF_ONE",
                    "participantCapacity": e["cap"], "roundCount": round_count},
         "stages": stages or [], "tournamentRegistrants": registrants or [], "tournamentParticipants": participants or []}
    return t

def registrant(pid, status="REGISTERED", checked=False):
    return {"id": f"reg-{pid}", "status": status, "checkedIn": checked, "player": player(pid)}

def participant(pid, status="ACTIVE", seed=None):
    return {"id": f"part-{pid}", "type": "PLAYER", "esportsTeamId": f"T{pid}", "status": status, "position": seed, "player": player(pid)}

def write(name, data):
    json.dump({"data": data}, open(os.path.join(out, name + ".json"), "w"), ensure_ascii=False)

E = {e["id"]: e for e in d["events"]}
ids = [p["id"] for p in d["players"]]

# --- the live event e1: the mock's three rounds, round 3 running -------------------------------------
def live_e1(my_result=None, dropped=False):
    e = E["e1"]
    start = now - timedelta(minutes=110)
    rounds = json.loads(json.dumps(d["rounds"]))
    if my_result:
        for t in rounds[2]["tables"]:
            if 0 in (t["a"], t["b"]): t["res"] = my_result
    rr = []
    for i, r in enumerate(rounds):
        n = r["n"]
        started = start + timedelta(minutes=55 * i) if n < 3 else now - timedelta(minutes=21, seconds=30)
        matches = [match(f"m{n}{t['t']:02d}", t["t"], t["a"], t["b"], t["res"]) for t in r["tables"]]
        rr.append({"roundNumber": n, "status": "FINALIZED" if n < 3 else "IN_PROGRESS", "startedAt": iso(started), "roundDuration": 50,
                   "byeTeamIds": [f"T{r['bye']}"] if r.get("bye") is not None else [], "droppedTeamIds": [],
                   "matches": matches, "endOfRoundStandings": standings(rounds, n, ids) if n < 3 else []})
    parts = [participant(p["id"], "DROPPED" if (p["dropped"] or (dropped and p["id"] == 0)) else "ACTIVE", p["seed"]) for p in d["players"]]
    regs = [registrant(p["id"], checked=True) for p in d["players"]]
    t = tournament(e, stages=[{"esportsStageId": "st", "name": "Swiss", "sections": [{"esportsSectionId": "sw", "rounds": rr}]}],
                   participants=parts, registrants=regs, round_count=d["planned"], desc=d["desc"])
    t["startsAt"] = iso(start)
    return t

def tour_file(t): return {"competeTournaments": [t]}

write("GetCompeteTournamentForRiftboundPlayer-e1", tour_file(live_e1()))
os.makedirs(os.path.join(out, "after-SubmitGameResults"), exist_ok=True)
json.dump({"data": tour_file(live_e1(my_result={"w": 0, "a": 2, "b": 1}))}, open(os.path.join(out, "after-SubmitGameResults", "GetCompeteTournamentForRiftboundPlayer-e1.json"), "w"), ensure_ascii=False)
os.makedirs(os.path.join(out, "after-DropCompetePlayerFromTournament"), exist_ok=True)
json.dump({"data": tour_file(live_e1(dropped=True))}, open(os.path.join(out, "after-DropCompetePlayerFromTournament", "GetCompeteTournamentForRiftboundPlayer-e1.json"), "w"), ensure_ascii=False)

# --- upcoming events: registered, 2v2, waitlisted; the rest open to register --------------------------
others = [p["id"] for p in d["players"] if p["id"] != 0]
for eid in ["e2", "e3", "e4", "e5", "e6", "e7", "e8", "e9"]:
    e = E[eid]
    count = min(e["players"], len(others))
    regs = [registrant(pid) for pid in others[:count - (1 if e["reg"] != "none" else 0)]]
    if e["reg"] == "registered": regs.insert(3, registrant(0))
    if e["reg"] == "waitlisted": regs.append(registrant(0, "WAITLISTED"))
    rc = int(e["meta"].split(" ")[0]) if e["meta"][0].isdigit() else None
    write(f"GetCompeteTournamentForRiftboundPlayer-{eid}", tour_file(tournament(e, registrants=regs, round_count=rc)))
reg_e5 = [registrant(pid) for pid in others[:E["e5"]["players"]]] + [registrant(0)]
os.makedirs(os.path.join(out, "after-RegisterCompetePlayer"), exist_ok=True)
json.dump({"data": tour_file(tournament(E["e5"], registrants=reg_e5, round_count=4))}, open(os.path.join(out, "after-RegisterCompetePlayer", "GetCompeteTournamentForRiftboundPlayer-e5.json"), "w"), ensure_ascii=False)

# --- past events: Swiss + top cut (3rd -> Top 4, Top 8), Swiss only (1st), casual (no rounds) ---------
def swiss_rounds(players, n_rounds, my_results, prefix):
    """Random pairings; my matches follow my_results ('W','L','D')."""
    rounds = []
    for r in range(1, n_rounds + 1):
        pool = [p for p in players if p != 0]
        random.shuffle(pool)
        tables = []
        opp = pool.pop()
        res = my_results[r - 1]
        tables.append({"t": 1, "a": 0, "b": opp, "res": {"w": 0, "a": 2, "b": random.choice([0, 1])} if res == "W" else {"w": opp, "a": random.choice([0, 1]), "b": 2} if res == "L" else {"w": -1, "a": 1, "b": 1}})
        while len(pool) >= 2:
            a, b = pool.pop(), pool.pop()
            w = random.choice([a, b])
            tables.append({"t": len(tables) + 1, "a": a, "b": b, "res": {"w": w, "a": 2 if w == a else random.choice([0, 1]), "b": 2 if w == b else random.choice([0, 1])}})
        rounds.append({"n": r, "tables": tables, "bye": pool[0] if pool else None})
    return rounds

def past(eid, players, n_rounds, my_results, cut=None):
    e = E[eid]
    rounds = swiss_rounds(players, n_rounds, my_results, eid)
    rr = [{"roundNumber": r["n"], "status": "FINALIZED", "startedAt": iso(when(e) + timedelta(minutes=55 * (r["n"] - 1))), "roundDuration": 50,
           "byeTeamIds": [f"T{r['bye']}"] if r.get("bye") is not None else [],
           "matches": [match(f"{eid}m{r['n']}{t['t']:02d}", t["t"], t["a"], t["b"], t["res"]) for t in r["tables"]],
           "endOfRoundStandings": standings(rounds, r["n"], players)} for r in rounds]
    sections = [{"esportsSectionId": "sw", "rounds": rr}]
    structure = "SWISS"
    if cut:
        structure = "SWISS_PLUS_SINGLE_ELIM"
        final = rr[-1]["endOfRoundStandings"]
        top = [int(s["esportsTeamId"][1:]) for s in final[:8]]
        if 0 not in top: top[-1] = 0
        alive = top
        cr = []
        for k, size in enumerate([8, 4, 2]):
            nxt = []
            ms = []
            for i in range(0, len(alive), 2):
                a, b = alive[i], alive[i + 1]
                if 0 in (a, b):
                    w = 0 if (size == 8 and cut != "QF") else (b if a == 0 else a)
                else:
                    w = random.choice([a, b])
                nxt.append(w)
                ms.append(match(f"{eid}c{size}{i}", i // 2 + 1, a, b, {"w": w, "a": 2 if w == a else 1, "b": 2 if w == b else 1}))
            cr.append({"roundNumber": k + 1, "status": "FINALIZED", "startedAt": iso(when(e) + timedelta(hours=5 + k)), "roundDuration": 50, "byeTeamIds": [], "matches": ms, "endOfRoundStandings": []})
            alive = nxt
        sections.append({"esportsSectionId": "cut", "rounds": cr})
    parts = [participant(p, "ACTIVE", i + 1) for i, p in enumerate(players)]
    return tournament(e, stages=[{"esportsStageId": "st", "sections": sections}], participants=parts,
                      registrants=[registrant(p, checked=True) for p in players], round_count=n_rounds, structure=structure)

write("GetCompeteTournamentForRiftboundPlayer-p1", tour_file(past("p1", ids[:20], 5, ["W", "W", "L", "W", "W"], cut="SF")))
write("GetCompeteTournamentForRiftboundPlayer-p2", tour_file(past("p2", ids[:8], 3, ["W", "W", "W"])))
write("GetCompeteTournamentForRiftboundPlayer-p3", tour_file(past("p3", ids[:24], 5, ["W", "L", "W", "D", "W"], cut="QF")))
write("GetCompeteTournamentForRiftboundPlayer-p4", tour_file(tournament(E["p4"], registrants=[registrant(p, checked=True) for p in ids[:11]])))

# --- lists ----------------------------------------------------------------------------------------------
def conn(items): return {"edges": [{"cursor": str(i), "node": x} for i, x in enumerate(items)], "pageInfo": {"endCursor": None, "hasNextPage": False}}
upcoming = [entry(E[i]) for i in ["e1", "e2", "e3", "e4"]]
upcoming[0]["tournament"]["startsAt"] = iso(now - timedelta(minutes=110))
past_list = [entry(E[i]) for i in ["p1", "p2", "p3", "p4"]]
write("PlayerTournaments", {"playerTournaments": {"upcoming": conn(upcoming), "past": conn(past_list)}})
search = []
for i in ["e1", "e2", "e3", "e4", "e5", "e6", "e7", "e8", "e9"]:
    x = entry(E[i])
    x["distanceMeters"] = next(s for s in d["stores"] if s["id"] == E[i]["store"])["km"] * 1000.0
    search.append(x)
search[0]["tournament"]["startsAt"] = iso(now - timedelta(minutes=110))
write("CompeteTournamentSearch", {"competeTournamentSearch": conn(search)})
write("FavoritedOrganizers", {"favoritedOrganizers": [organizer(s["id"]) for s in d["stores"] if s["fav"]]})
for s in d["stores"]:
    o = organizer(s["id"])
    write(f"OrganizerSummary-{s['id']}", {"organizerSummary": {"id": s["id"], "name": s["name"], "email": s["mail"], "website": s["web"],
                                                              "phone": {"countryDialingCode": "+49", "number": s["phone"].replace("+49 ", "")},
                                                              "physicalAddress": o["physicalAddress"], "type": "STORE"}})
json.dump({"gameName": "Okay", "tagLine": "EUW"}, open(os.path.join(out, "session.json"), "w"))
# The apps move every time by (switch turned on - this), so the event is live whenever it is tested.
json.dump({"generatedAt": iso(now)}, open(os.path.join(out, "_meta.json"), "w"))
print("wrote", len(os.listdir(out)), "files to", out)
