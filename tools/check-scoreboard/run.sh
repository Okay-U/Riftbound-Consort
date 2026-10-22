#!/bin/sh
# Checks the redesign's scoreboard rules (Redesign/Score) case by case like the Android unit tests
# check ScoreRules.kt, Duel.kt and the result picker. Run after touching those files:
#   sh tools/check-scoreboard/run.sh
set -e
here="$(cd "$(dirname "$0")" && pwd)"
app="$here/../../Riftbound Companiokay"
tmp=$(mktemp -d)
xcrun swiftc -O -o "$tmp/check" "$here/main.swift" \
  "$app/Redesign/Score/ScoreRules.swift" "$app/Redesign/Score/FirstRoll.swift" "$app/User/ScoreEvent.swift"
"$tmp/check"
rm -rf "$tmp"
