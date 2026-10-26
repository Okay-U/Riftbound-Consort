#!/bin/sh
# Builds the debug "Fake live event" data for both apps:
#   sh tools/fake-live-event/build.sh
# Android: android-native/app/src/debug/assets/fake_compete/ (debug builds only).
# iOS (when the redesign is checked out): Redesign/Events/FakeLiveEventData.swift, compiled in DEBUG only.
# The two biggest past events are left out; their cards show no placement.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../.."
tmp=$(mktemp -d)
python3 -I "$here/sample.py" > "$tmp/sample.json"
python3 -I "$here/compete.py" "$tmp/sample.json" "$tmp/out" > /dev/null
rm -f "$tmp/out/GetCompeteTournamentForRiftboundPlayer-p1.json" "$tmp/out/GetCompeteTournamentForRiftboundPlayer-p3.json"
assets="$root/android-native/app/src/debug/assets/fake_compete"
rm -rf "$assets" && mkdir -p "$assets" && cp -R "$tmp/out/." "$assets/"
ios="$root/Riftbound Companiokay/Redesign/Events"
if [ -d "$ios" ]; then python3 -I "$here/swift.py" "$tmp/out" "$ios/FakeLiveEventData.swift"; fi
rm -rf "$tmp"
echo "fake live event data written"
