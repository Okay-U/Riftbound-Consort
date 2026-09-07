# Riftcount (Android)

[Skip](https://skip.dev) Fuse app: compiled Swift + SkipUI → Compose. Module `Riftcount`,
appId `pitopia.Riftcount`, package `riftcount.module`. Sources in `Sources/Riftcount/`, Gradle
shell in `Android/`, version in `Skip.env`.

- Compile gate: `skip android build`
- Run on a booted emulator (`emulator -avd SkipSpike`): `skip app launch --android`
- Release: `skip export` → `.build/skip-export/Riftcount-release.{apk,aab}`. Needs
  `Android/app/keystore.properties` (gitignored) or it signs with the debug key.

Conventions, SkipUI gotchas and the iOS-parity rule: repo `CLAUDE.md`.
