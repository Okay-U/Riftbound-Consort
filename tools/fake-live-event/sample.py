# sample.py > sample.json : fictional tournament data from the Events mocks (invented players, stores and contacts).
import json, random
random.seed(21)
legends = ["Kai'Sa", 'Volibear', 'Jinx', 'Darius', 'Ahri', 'Lee Sin', 'Yasuo', 'Leona', 'Viktor', 'Sett', 'Annie', 'Garen']
names = ['You', 'Mara K.', 'Jonas B.', 'Lena V.', 'Tarik O.', 'Sven H.', 'Ida M.', 'Felix R.', 'Noah S.', 'Emre Y.', 'Clara W.', 'Ben L.',
         'Yuki T.', 'Paul D.', 'Nina F.', 'Luca G.', 'Aylin C.', 'Tim P.', 'Hanna E.', 'Milo Z.', 'Sara N.', 'Kai U.', 'Jana A.', 'Oskar I.']
P = [{'id': i, 'name': n, 'legend': legends[(i * 5) % len(legends)], 'skill': random.random() + (0.45 if i == 0 else 0.25 if i == 1 else 0), 'seed': 0, 'dropped': False} for i, n in enumerate(names)]
P[0]['legend'] = 'Poppy'
for k, i in enumerate(random.sample(range(24), 24)): P[i]['seed'] = k + 1
rec = {p['id']: {'w': 0, 'l': 0, 'd': 0, 'gw': 0, 'gl': 0, 'opps': [], 'bye': 0} for p in P}
def apply(res, a, b):
    if res['w'] == -1:
        for i in (a, b): rec[i]['d'] += 1; rec[i]['gw'] += 1; rec[i]['gl'] += 1
        return
    w = res['w']; lo = b if w == a else a
    ga, gb = res['a'], res['b']
    rec[w]['w'] += 1; rec[lo]['l'] += 1
    rec[a]['gw'] += ga; rec[a]['gl'] += gb; rec[b]['gw'] += gb; rec[b]['gl'] += ga
def play(a, b):
    for star in (0, 1):
        if star in (a, b):
            two_one = star == 0 and len(rec[0]['opps']) == 1
            return {'w': star, 'a': 2 if a == star else (1 if two_one else 0), 'b': 2 if b == star else (1 if two_one else 0)}
    if random.random() < 0.07: return {'w': -1, 'a': 1, 'b': 1}
    pa, pb = P[a]['skill'], P[b]['skill']
    awins = random.random() < pa / (pa + pb)
    two_one = random.random() < 0.45
    return {'w': a if awins else b, 'a': (2 if awins else (1 if two_one else 0)), 'b': ((1 if two_one else 0) if awins else 2)}
def pts(i): return rec[i]['w'] * 3 + rec[i]['d'] + rec[i]['bye'] * 3
def pair(active):
    order = sorted(active, key=lambda i: (-pts(i), random.random()))
    bye = None
    if len(order) % 2: bye = order.pop()  # lowest gets the bye
    pairs, used = [], set()
    for i in order:
        if i in used: continue
        for j in order:
            if j != i and j not in used and j not in rec[i]['opps'] and {i, j} != {0, 1}:
                pairs.append((i, j)); used.add(i); used.add(j); break
    return pairs, bye
def mwp(i):
    r = rec[i]; n = r['w'] + r['l'] + r['d']
    return max(1 / 3, (r['w'] * 3 + r['d']) / (3 * n)) if n else 1 / 3
def gwp(i):
    r = rec[i]; n = r['gw'] + r['gl']
    return max(1 / 3, r['gw'] / n) if n else 1 / 3
def table():
    rows = []
    for p in P:
        i = p['id']; r = rec[i]; o = [x for x in r['opps'] if x is not None]
        rows.append({'id': i, 'pts': pts(i), 'w': r['w'] + r['bye'], 'l': r['l'], 'd': r['d'],
                     'omw': round(sum(mwp(x) for x in o) / len(o) * 100, 1) if o else 33.3,
                     'gw': round(gwp(i) * 100, 1), 'ogw': round(sum(gwp(x) for x in o) / len(o) * 100, 1) if o else 33.3,
                     'dropped': p['dropped']})
    rows.sort(key=lambda s: (-s['pts'], -s['omw'], -s['gw'], -s['ogw']))
    rank = 0; last = None
    for k, s in enumerate(rows):
        key = (s['pts'], s['omw'], s['gw'], s['ogw'])
        if key != last: rank = k + 1; last = key
        s['rank'] = rank
    return rows
rounds, after = [], {}
for rnd in (1, 2, 3):
    active = [p['id'] for p in P if not p['dropped']]
    pairs, bye = pair(active)
    if rnd == 3:
        pairs = [pp for pp in pairs if 0 not in pp and 1 not in pp]
        free = [i for i in active if all(i not in pp for pp in pairs) and i not in (0, 1) and i != bye]
        while len(free) >= 2: pairs.append((free.pop(), free.pop()))
        pairs = pairs[:4] + [(0, 1)] + pairs[4:]
    tabs = []
    for t, (a, b) in enumerate(pairs):
        live = rnd == 3 and t in (4, 6, 8, 9, 10)
        res = None if live else play(a, b)
        if res: apply(res, a, b)
        rec[a]['opps'].append(b); rec[b]['opps'].append(a)
        tabs.append({'t': t + 1, 'a': a, 'b': b, 'res': res})
    if bye is not None: rec[bye]['bye'] += 1
    rounds.append({'n': rnd, 'tables': tabs, 'bye': bye, 'start': ['18:34', '19:28', '20:21'][rnd - 1], 'len': 50, 'live': rnd == 3})
    if rnd < 3: after[rnd] = table()
    if rnd == 2: P[17]['dropped'] = True
live = table()
playing = [x for t in rounds[2]['tables'] if t['res'] is None for x in (t['a'], t['b'])]
reported = sum(1 for t in rounds[2]['tables'] if t['res'] is not None)
stores = [
    {'id': 's1', 'name': 'Spielwiese', 'city': 'Stuttgart', 'addr': 'Königstraße 12, 70173 Stuttgart', 'km': 2, 'fav': True, 'web': 'spielwiese.example', 'mail': 'hallo@spielwiese.example', 'phone': '+49 711 0000 100'},
    {'id': 's2', 'name': 'Kartenhaus', 'city': 'Esslingen', 'addr': 'Bahnhofstraße 3, 73728 Esslingen', 'km': 11, 'fav': True, 'web': 'kartenhaus.example', 'mail': 'team@kartenhaus.example', 'phone': '+49 711 0000 200'},
    {'id': 's3', 'name': 'Spielraum', 'city': 'Waiblingen', 'addr': 'Lange Straße 40, 71332 Waiblingen', 'km': 13, 'fav': False, 'web': 'spielraum.example', 'mail': 'info@spielraum.example', 'phone': '+49 7151 0000 30'},
    {'id': 's4', 'name': 'Drachenhort', 'city': 'Ludwigsburg', 'addr': 'Marktplatz 7, 71634 Ludwigsburg', 'km': 15, 'fav': False, 'web': 'drachenhort.example', 'mail': 'post@drachenhort.example', 'phone': '+49 7141 0000 40'},
    {'id': 's5', 'name': 'Tisch & Würfel', 'city': 'Böblingen', 'addr': 'Poststraße 21, 71032 Böblingen', 'km': 18, 'fav': False, 'web': 'tischwuerfel.example', 'mail': 'hi@tischwuerfel.example', 'phone': '+49 7031 0000 50'},
    {'id': 's6', 'name': 'Nexus Corner', 'city': 'Reutlingen', 'addr': 'Wilhelmstraße 88, 72764 Reutlingen', 'km': 31, 'fav': False, 'web': 'nexuscorner.example', 'mail': 'play@nexuscorner.example', 'phone': '+49 7121 0000 60'},
]
E = [
    {'id': 'e1', 'name': 'Summoner Skirmish · Spiritforged', 'program': 'Summoner Skirmish', 'store': 's1', 'day': 21, 'mon': 'OCT', 'dow': 'Tue', 'time': '18:30', 'fmt': 'Constructed • 1v1 • Swiss', 'meta': '5 rounds • Best of three • €5', 'price': '€5', 'players': 24, 'cap': 32, 'status': 'live', 'reg': 'registered', 'mine': True, 'kind': 'live'},
    {'id': 'e2', 'name': 'Nexus Night · Sealed', 'program': 'Nexus Night', 'store': 's2', 'day': 24, 'mon': 'OCT', 'dow': 'Fri', 'time': '19:00', 'fmt': 'Sealed • 1v1 • Swiss', 'meta': '4 rounds • Best of one • €12', 'price': '€12', 'players': 10, 'cap': 16, 'status': 'upcoming', 'reg': 'registered', 'mine': True},
    {'id': 'e3', 'name': '2v2 Night', 'program': 'Open Play', 'store': 's1', 'day': 29, 'mon': 'OCT', 'dow': 'Wed', 'time': '18:30', 'fmt': 'Constructed • 2v2 • Swiss', 'meta': '3 rounds • Best of three • €8', 'price': '€8', 'players': 12, 'cap': 24, 'status': 'upcoming', 'reg': 'registered', 'mine': True, 'mate': 'Jonas B.'},
    {'id': 'e4', 'name': 'Pre-Rift · Unleashed', 'program': 'Pre-Rift', 'store': 's5', 'day': 1, 'mon': 'NOV', 'dow': 'Sat', 'time': '11:00', 'fmt': 'Sealed • 1v1 • Swiss', 'meta': '5 rounds • Best of one • €25', 'price': '€25', 'players': 40, 'cap': 40, 'status': 'upcoming', 'reg': 'waitlisted', 'mine': True},
    {'id': 'e5', 'name': 'Summoner Skirmish · Constructed', 'program': 'Summoner Skirmish', 'store': 's4', 'day': 25, 'mon': 'OCT', 'dow': 'Sat', 'time': '14:00', 'fmt': 'Constructed • 1v1 • Swiss', 'meta': '4 rounds • Best of three • €5', 'price': '€5', 'players': 18, 'cap': 32, 'status': 'upcoming', 'reg': 'none', 'mine': False},
    {'id': 'e6', 'name': 'Open Play', 'program': 'Open Play', 'store': 's2', 'day': 23, 'mon': 'OCT', 'dow': 'Thu', 'time': '18:00', 'fmt': 'Casual • 1v1', 'meta': 'Drop in, no rounds • Free', 'price': 'Free', 'players': 6, 'cap': 30, 'status': 'upcoming', 'reg': 'none', 'mine': False},
    {'id': 'e7', 'name': 'Summoner Skirmish · Sealed', 'program': 'Summoner Skirmish', 'store': 's6', 'day': 25, 'mon': 'OCT', 'dow': 'Sat', 'time': '13:00', 'fmt': 'Sealed • 1v1 • Swiss', 'meta': '4 rounds • Best of one • €20', 'price': '€20', 'players': 12, 'cap': 24, 'status': 'upcoming', 'reg': 'none', 'mine': False},
    {'id': 'e8', 'name': 'Nexus Night · Constructed', 'program': 'Nexus Night', 'store': 's3', 'day': 28, 'mon': 'OCT', 'dow': 'Tue', 'time': '19:00', 'fmt': 'Constructed • 1v1 • Swiss', 'meta': '3 rounds • Best of three • €5', 'price': '€5', 'players': 9, 'cap': 16, 'status': 'upcoming', 'reg': 'none', 'mine': False},
    {'id': 'e9', 'name': 'Learn to Play', 'program': 'Learn to Play', 'store': 's3', 'day': 2, 'mon': 'NOV', 'dow': 'Sun', 'time': '15:00', 'fmt': 'Starter decks • 1v1', 'meta': 'Guided games • Free', 'price': 'Free', 'players': 4, 'cap': 12, 'status': 'upcoming', 'reg': 'none', 'mine': False},
    {'id': 'p1', 'name': 'Summoner Skirmish · Spiritforged', 'program': 'Summoner Skirmish', 'store': 's1', 'day': 14, 'mon': 'OCT', 'dow': 'Tue', 'time': '18:30', 'fmt': 'Constructed • 1v1 • Swiss + Top 8', 'meta': '5 rounds • Best of three • €5', 'price': '€5', 'players': 20, 'cap': 32, 'status': 'past', 'reg': 'registered', 'mine': True, 'place': '3rd', 'rec': '4-1-0 · 12 pts after Swiss', 'medal': 'medal'},
    {'id': 'p2', 'name': 'Nexus Night · Draft', 'program': 'Nexus Night', 'store': 's2', 'day': 10, 'mon': 'OCT', 'dow': 'Fri', 'time': '19:00', 'fmt': 'Draft • 1v1 • Swiss', 'meta': '3 rounds • Best of one • €15', 'price': '€15', 'players': 8, 'cap': 8, 'status': 'past', 'reg': 'registered', 'mine': True, 'place': '1st', 'rec': '3-0-0 · 9 pts', 'medal': 'crown'},
    {'id': 'p3', 'name': 'Summoner Skirmish · Origins', 'program': 'Summoner Skirmish', 'store': 's4', 'day': 30, 'mon': 'SEP', 'dow': 'Tue', 'time': '18:00', 'fmt': 'Constructed • 1v1 • Swiss + Top 8', 'meta': '5 rounds • Best of three • €5', 'price': '€5', 'players': 26, 'cap': 32, 'status': 'past', 'reg': 'registered', 'mine': True, 'place': 'Top 8', 'rec': '3-1-1 · 10 pts after Swiss', 'medal': 'none'},
    {'id': 'p4', 'name': 'Open Play', 'program': 'Open Play', 'store': 's1', 'day': 26, 'mon': 'SEP', 'dow': 'Fri', 'time': '17:00', 'fmt': 'Casual • 1v1', 'meta': 'Drop in, no rounds • Free', 'price': 'Free', 'players': 11, 'cap': 30, 'status': 'past', 'reg': 'registered', 'mine': True, 'place': '', 'rec': 'No standings for casual play', 'medal': 'none'},
]
data = {
    'players': [{'id': p['id'], 'name': p['name'], 'legend': p['legend'], 'seed': p['seed'], 'dropped': p['dropped']} for p in P],
    'rounds': rounds, 'after': after, 'live': live, 'playing': playing, 'reported': reported, 'planned': 5, 'cut': 8,
    'stores': stores, 'events': E,
    'desc': 'Weekly Summoner Skirmish for Spiritforged. Bring a legal Constructed deck, sleeves and a playmat. Pairings and results run on PlayRiftbound; the top 8 after Swiss play single elimination for the playmat.',
}
print(json.dumps(data, ensure_ascii=False, separators=(',', ':')))
