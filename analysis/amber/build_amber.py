#!/usr/bin/env python3
"""Build the Riftbound AMBER card table: amber.json (data) and amber.html (grid view).

Method and prices: J. Chen and J. C. Lee, "Recovering the Designer's Ledger: Inverse Hedonic
Pricing of Card Costs in a Collectible Card Game", preprint v3, 2026,
https://doi.org/10.5281/zenodo.22950820 (CC BY 4.0). Frozen model v6 and the per-card value
table: preregistration record https://doi.org/10.5281/zenodo.22950713 (CC BY 4.0).

Sources per card:
  authors  value from the authors' frozen v6 card value table (inputs/authors_v6_card_values.csv),
           calculation note translated to English (inputs/authors_calc_en.json).
  blind    cards the authors did not publish (Radiance, set-aside older cards), priced by us with
           the frozen v6 rules from rules text only, costs hidden (inputs/blind_v6_pricing.json).

AMBER score (paper Eq. 3): (V0 + k * (V1 - V0)) / C, C = energy + 2 * power.
k = 0.5 for a unit's repeatable trigger, 0.25 when the trigger needs an independent condition,
0 otherwise. Card art and text: Riot Games card gallery via okay-u.github.io/cards.json.

Usage: python3 build_amber.py [cards.json path or URL]
"""
from __future__ import annotations

import csv
import json
import re
import statistics
import sys
import urllib.request
from pathlib import Path
from typing import Any

Card = dict[str, Any]

HERE = Path(__file__).resolve().parent
CARDS_URL = 'https://okay-u.github.io/cards.json'
AUTHORS_CSV = HERE / 'inputs' / 'authors_v6_card_values.csv'
CALC_EN = HERE / 'inputs' / 'authors_calc_en.json'
BLIND = HERE / 'inputs' / 'blind_v6_pricing.json'
TEMPLATE = HERE / 'amber_template.html'

K_REPEAT, K_COND = 0.5, 0.25
LOW_COST_FACTOR = 0.30          # on-play effects and sub-1 C native keywords on units with C <= 3
FLOW_K = 0.2                     # Flow keyword: 0.2 * max(0, 1 - (flow cost - C))
BAND_LOW, BAND_HIGH, BAND_FAR = 0.86, 1.17, 1.50

# The paper books 17 "conditional" repeatable triggers at 0.25; the list is not public. Rebuilt from
# the paper's definition (Sec. III-D); it reproduces the paper's fingerprint (14 of 17 closer at 0.25,
# 11 cards >= 1.50, 180 at exactly 1.00). ponytail: judgement list, swap for the authors' list once released.
COND_TRIGGERS = {
    'OGN-034', 'OGN-205', 'VEN-065', 'SFD-041', 'VEN-138', 'VEN-042', 'UNL-018', 'VEN-016', 'VEN-005',
    'VEN-006', 'UNL-143', 'OGN-131', 'VEN-024', 'UNL-196', 'VEN-125', 'UNL-079', 'OGN-056',
}
STATUS = {'完整': 'full', '部分 / 下限 / 低可信': 'partial', '暂不估（数值仅为已定价部分的下限）': 'deferred'}
LEDGER_TYPE = {'单位': 'Unit', '法术': 'Spell', '装备': 'Gear'}


def num(s: Any) -> float | None:
    s = '' if s is None else str(s).strip()
    return float(s) if s not in ('', 'None', 'nan') else None


def load_json(src: str | Path) -> Any:
    if re.match(r'https?://', str(src)):
        with urllib.request.urlopen(src, timeout=60) as r:
            return json.load(r)
    return json.loads(Path(src).read_text(encoding='utf-8'))


GEAR_TEXT = re.compile(r'\[Deploy\]|When I become exhausted|When you play this,|\bkill this\b|\bthis gear\b|(^|\n)(Exhaust|Kill this)[^\n]*:', re.I)


def preview_type(t: str | None, might: Any, text: str) -> str:
    """Riot's preview data mislabels some Radiance types (e.g. a spell tagged Unit); read the type off the card."""
    equipment = '[Equip]' in text or text.startswith('Equip ')
    if might is not None and not (t == 'Gear' and equipment):
        return 'Unit'
    if t == 'Gear':
        return t
    if GEAR_TEXT.search(re.sub(r'\([^)]*\)', '', text)):  # ignore reminder text
        return 'Gear'
    return 'Spell'


def costed_cards(feed: dict[str, Any]) -> list[Card]:
    """One entry per distinct costed card (unit, spell, gear); reprints and alt arts collapse."""
    def ctype(i: dict[str, Any]) -> str:
        t = (i.get('classification') or {}).get('type')
        if t or i['attributes'].get('energy') is None:
            return t or 'Reminder'  # untyped, uncosted: Buff / XP Tracker reminder cards
        return 'Unit' if i['attributes'].get('might') is not None else 'Spell'

    def rank(i: dict[str, Any]) -> tuple[bool, bool, bool, str]:
        m = i['metadata']
        return (bool(m.get('alternate_art')), bool(m.get('signature')), bool(m.get('overnumbered')), i['public_code'])

    groups = {}
    for i in feed['items']:
        t = ctype(i)
        if i.get('unreleased') and i['attributes'].get('energy') is not None:
            t = preview_type((i.get('classification') or {}).get('type'), i['attributes'].get('might'), i['text']['plain'] or '')
        if t in ('Unit', 'Spell', 'Gear'):
            name = re.sub(r'\s*\((Alternate Art|Overnumbered|Signature)\)\s*$', '', i['name']).strip()
            groups.setdefault((name, t), []).append(i)
    cards = []
    for (name, t), prints in groups.items():
        prints.sort(key=rank)
        rep, at = prints[0], prints[0]['attributes']
        e, p = at.get('energy') or 0, at.get('power') or 0
        if e + p == 0:
            continue  # zero-cost tokens: no ratio, the paper excludes them
        cls = rep.get('classification') or {}
        cards.append(dict(
            id=rep['public_code'].split('/')[0].rstrip('a*'), codes=sorted({x['public_code'].split('/')[0].rstrip('a*') for x in prints}),
            name=name, type=t, set=rep['set']['set_id'], domain=cls.get('domain') or [], rarity=cls.get('rarity'),
            E=e, P=p, C=e + 2 * p, might=at.get('might'), text=rep['text']['plain'] or '',
            image=rep['media']['image_url'], preview=bool(rep.get('unreleased'))))
    return cards


def band(a: float | None) -> str:
    if a is None:
        return 'none'
    if a < BAND_LOW:
        return 'under'
    if a <= BAND_HIGH:
        return 'on'
    return 'far' if a >= BAND_FAR else 'above'


def finish(rec: Card, v0: float | None, delta: float, k: float, eta_nominal: float | None) -> Card:
    """Attach nominal ratio, AMBER score and band; spells and gear have k = 0."""
    c = rec['C']
    base = {**rec, 'V0': v0, 'delta': delta, 'k': k, 'eta': eta_nominal}
    if eta_nominal is None or rec['status'] == 'deferred' or not c:
        return {**base, 'amber': None, 'band': 'none'}
    amber = eta_nominal + (k * delta / c if delta else 0.0)
    return {**base, 'amber': round(amber, 4), 'band': band(amber)}


def authors_eta(v0: float | None, eta_table: float | None, c: int) -> float | None:
    """Unrounded V0 / C; the table's own ratio only where it uses another denominator (Quick-Draw equipment)."""
    if v0 is None or not c:
        return eta_table
    return eta_table if eta_table is not None and abs(eta_table - v0 / c) > 0.006 else v0 / c


def authors_record(card: Card, row: dict[str, str], calc: dict[str, str]) -> Card:
    status = STATUS.get(row['分组'], 'deferred')
    ledger_type = LEDGER_TYPE[row['类型']]
    b0, b1 = num(row['每当×0']), num(row['每当×1'])
    delta = b1 - b0 if ledger_type == 'Unit' and b0 is not None and b1 is not None and b1 > b0 else 0.0
    k = (K_COND if card['id'] in COND_TRIGGERS else K_REPEAT) if delta else 0.0
    rec = dict(card, source='authors', status=status, status_detail=calc.get('status_detail', ''),
               calc=calc.get('calc', ''), components=None, reason='', ledger_type=ledger_type,
               V_full=num(row['全触发价值']), eta_full=num(row['全触发性价比']),
               bins=[num(row[f'每当×{n}']) for n in range(4)], cond_trigger=card['id'] in COND_TRIGGERS,
               flow=[num(row[x]) for x in ('流转词条价值', '只打第一次收益', '流转那次收益', '流转费用', '两次都打收益')])
    v0 = num(row['基础价值'])
    return finish(rec, v0, delta, k, authors_eta(v0, num(row['η']), card['C']))


def blind_components(card: Card, comps: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Apply the two cost-dependent factors the blind pricer could only flag."""
    low = card['C'] <= 3 and card['type'] == 'Unit'
    out = []
    for comp in comps:
        v = float(comp['value'])
        factor = LOW_COST_FACTOR if low and (comp.get('lowcost_onplay') or comp.get('native_kw_sub1')) else 1.0
        out.append(dict(label=comp['label'], rule=comp.get('rule', ''), value=v, factor=factor, booked=round(v * factor, 4)))
    return out


def blind_record(card: Card, pr: dict[str, Any]) -> Card:
    comps = blind_components(card, pr.get('components') or [])
    v0 = sum(c['booked'] for c in comps)
    fc = pr.get('flow_cost')
    flow_k = FLOW_K * max(0.0, 1 - ((fc.get('E') or 0) + 2 * (fc.get('P') or 0) - card['C'])) if fc and card['C'] else 0.0
    if flow_k:
        comps = comps + [dict(label='Flow keyword', rule='k = 0.2 x max(0, 1 - (Flow cost - C))', value=flow_k, factor=1.0, booked=round(flow_k, 4))]
        v0 += flow_k
    trig = pr.get('trigger') or None
    delta = float(trig['V1_minus_V0']) if trig and card['type'] == 'Unit' and float(trig['V1_minus_V0']) > 0 else 0.0
    cond = bool(trig and trig.get('conditional'))
    k = (K_COND if cond else K_REPEAT) if delta else 0.0
    cb = pr.get('cond_bonus') or None
    rec = dict(card, source='blind', status=pr['status'], status_detail='', calc=pr.get('calc', ''), components=comps,
               reason=re.sub(r'^(deferred|partial)(/excluded)?\s*:\s*', '', pr.get('reason', '')), trigger_text=trig.get('text', '') if trig else '', cond_trigger=cond,
               cond_bonus=cb, V_full=None, eta_full=None, bins=None, flow=None, analogs=pr.get('analogs', []))
    v0 = round(v0, 4)
    return finish(rec, v0, delta, k, v0 / card['C'] if card['C'] else None)


def summarize(recs: list[Card], source: str) -> dict[str, Any] | None:
    xs = sorted(r['amber'] for r in recs if r['source'] == source and r['status'] == 'full'
                and r.get('ledger_type', r['type']) in ('Unit', 'Spell') and r['amber'] is not None)
    if not xs:
        return None
    q = statistics.quantiles(xs, n=4, method='inclusive')
    return dict(n=len(xs), median=round(statistics.median(xs), 3), q1=round(q[0], 3), q3=round(q[2], 3),
                mean=round(statistics.mean(xs), 3), above=sum(x > BAND_HIGH + 1e-9 for x in xs),
                far=sum(x >= BAND_FAR - 1e-9 for x in xs), par=sum(abs(x - 1) < 1e-9 for x in xs))


def radiance_test(recs: list[Card]) -> dict[str, Any] | None:
    """Unofficial replay of preregistered H1/H2 on Radiance: residual r = V0 - C over fully priced units and spells."""
    rs = [r for r in recs if r['set'] == 'RAD' and r['source'] == 'blind' and r['status'] == 'full'
          and r['type'] in ('Unit', 'Spell') and r['eta'] is not None]
    if not rs:
        return None
    res = [r['V0'] - r['C'] for r in rs]
    rmse = (sum(x * x for x in res) / len(res)) ** 0.5
    eta = statistics.median(r['eta'] for r in rs)
    return dict(n=len(rs), rmse=round(rmse, 3), h1_supported=rmse <= 1.841, median_eta=round(eta, 3),
                h2_supported=0.90 <= eta <= 1.10, mean_residual=round(statistics.mean(res), 3))


def selfcheck(stats: dict[str, Any]) -> None:
    """The authors' ledger must reproduce the paper's published AMBER distribution (Sec. VII-B)."""
    a = stats['authors']
    assert a['n'] == 497, a
    assert a['median'] == 1.0 and abs(a['mean'] - 0.972) < 0.005, a
    # Paper: 11 at >= 1.50, 180 at exactly 1.00, 62 above 1.17. The last two move by a card or two with
    # the unpublished conditional-trigger list, hence the tolerance.
    assert a['far'] == 11 and abs(a['par'] - 180) <= 2 and abs(a['above'] - 62) <= 2, a


def build(cards_src: str | Path) -> tuple[list[Card], dict[str, Any]]:
    cards = costed_cards(load_json(cards_src))
    rows = {r['卡号']: r for r in csv.DictReader(AUTHORS_CSV.open(encoding='utf-8-sig'))}
    calc = load_json(CALC_EN)
    blind = {p['id']: p for p in load_json(BLIND)} if BLIND.exists() else {}
    recs, missing = [], []
    for card in cards:
        row = next((rows[c] for c in card['codes'] if c in rows), None)
        if row:
            recs.append(authors_record(card, row, calc.get(row['卡号'], {})))
        elif card['id'] in blind:
            recs.append(blind_record(card, blind[card['id']]))
        else:
            missing.append(card['id'])
    recs.sort(key=lambda r: (r['set'], r['id']))
    stats = dict(authors=summarize(recs, 'authors'), blind=summarize(recs, 'blind'), radiance=radiance_test(recs),
                 counts={s: sum(r['status'] == s for r in recs) for s in ('full', 'partial', 'deferred')},
                 total=len(recs), missing=missing)
    selfcheck(stats)
    if missing:
        print(f'warning: {len(missing)} cards have no price yet and are left out: {missing}', file=sys.stderr)
    return recs, stats


def main() -> None:
    recs, stats = build(sys.argv[1] if len(sys.argv) > 1 else CARDS_URL)
    payload = dict(source='Chen & Lee 2026 (CC BY 4.0), frozen model v6; blind v6 pricing by Riftcount', stats=stats, cards=recs)
    (HERE / 'amber.json').write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding='utf-8')
    data = json.dumps(payload, ensure_ascii=False).replace('<', '\\u003c')  # no markup can close the script
    page = TEMPLATE.read_text(encoding='utf-8').replace('/*__DATA__*/null', data)
    (HERE / 'amber.html').write_text(page, encoding='utf-8')
    print(json.dumps(stats, indent=1))


if __name__ == '__main__':
    main()
