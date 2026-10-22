#!/bin/sh
# Checks the redesign's deck rules (Redesign/Decks/DeckRules.swift) case by case like the Android unit
# test DeckRulesTest, on the Android test fixture, and the match log's numbers (MatchLog.swift). Run after
# touching DeckRules, MatchLog or the card helpers:
#   sh tools/check-decks/run.sh
set -e
here="$(cd "$(dirname "$0")" && pwd)"
app="$here/../../Riftbound Companiokay"
tmp=$(mktemp -d)
xcrun swiftc -O -o "$tmp/check" "$here/main.swift" \
  "$app/Redesign/Decks/DeckRules.swift" "$app/Redesign/Cards/CardTraits.swift" \
  "$app/Cards/Card.swift" "$app/Cards/CardClassifier.swift" "$app/Cards/Decklist.swift" "$app/Cards/DeckLegality.swift" \
  "$app/Redesign/Decks/MatchLog.swift" "$app/Redesign/Score/ScoreRules.swift" "$app/Redesign/Score/FirstRoll.swift" \
  "$app/User/GameRecord.swift" "$app/User/ScoreEvent.swift"
"$tmp/check" "$here/../../android-native/app/src/test/resources/cards_fixture.json"
rm -rf "$tmp"
