# Skoväder – anteckningar för Claude Code

- Kraven finns i `docs/kravspec.md`, gjorda standardval i `docs/beslut.md`.
  Lägg nya standardval där. Fråga hellre än gissa om ett krav är oklart.
- Bygg i etapper enligt kravspecen och stanna efter varje etapp för
  avstämning med Linus. Commit efter varje etapp.
- Inga tredjepartspaket. Inget från "Utanför scope".
- Xcode-projektet genereras: ändra `project.yml`, kör `xcodegen generate`.
  `*.xcodeproj` och `App/Info.plist` checkas inte in.
- Regelmotorn (`Engine/`) får bara bero på Foundation. Alla tal ligger i
  `RecommendationConfig.swift`. Kör `swift test` i `Engine/` (eller
  `scripts/test-engine.sh`) efter varje ändring i motorn.
- Användartexter på svenska: UI i `Resources/Localizable.xcstrings`,
  motiveringar i motorns `sv.lproj/Localizable.strings`.
- Inga hemligheter i Git. API-nyckel för App Store Connect (sökväg, key-id,
  issuer-id) och team-id läses från miljövariabler eller
  `Config/Local.xcconfig`.
