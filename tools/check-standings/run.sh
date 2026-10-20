#!/bin/sh
# Recomputes PlayRiftbound standings with the app's CompeteStandings and compares them
# with Riot's official end-of-round tables of finished public events (no sign-in).
# Run after touching CompeteStandings.swift or CompeteModels.swift:  sh tools/check-standings/run.sh
set -e
here="$(cd "$(dirname "$0")" && pwd)"
events="$here/../../Riftbound Companiokay/User/Events"
id=$(grep -o '"GetCompeteTournamentForRiftboundPlayer": "[0-9a-f]\{64\}"' "$events/PlayRiftboundAPI.swift" | grep -o '[0-9a-f]\{64\}')
tmp=$(mktemp -d)
# A 30-player BO3 event with a bye and drops, an 8-player BO1 event with draws, a 16-player event with a bye.
for t in 117230601421798826 117303870491694585 117353827247396877; do
  curl -s -G "https://playriftbound.com/api/gql" \
    -H "Content-Type: application/json" -H "Accept: application/json" \
    -H "apollographql-client-name: Riftcount" -H "apollographql-client-version: check" \
    --data-urlencode "operationName=GetCompeteTournamentForRiftboundPlayer" \
    --data-urlencode "variables={\"tournamentId\":\"$t\"}" \
    --data-urlencode "extensions={\"persistedQuery\":{\"version\":1,\"sha256Hash\":\"$id\"}}" |
    python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin)["data"]["competeTournaments"][0]))' > "$tmp/$t.json"
done
xcrun swiftc -O -o "$tmp/check" "$here/main.swift" "$events/CompeteModels.swift" "$events/CompeteStandings.swift"
"$tmp/check" "$tmp"
rm -rf "$tmp"
