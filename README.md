# Skoväder

iPhone-app som föreslår vilka skor som passar dagens väder. Användaren
fotograferar sina skor, och varje morgon väljer en enkel regelmotor ett par
utifrån prognosen för 07–18. All data stannar på telefonen; enda
nätverksanropet är vädret (Open-Meteo).

- Krav: [docs/kravspec.md](docs/kravspec.md)
- Standardval där kraven var öppna: [docs/beslut.md](docs/beslut.md)

## Status

| Etapp | Innehåll | Status |
|---|---|---|
| 1. Grund | XcodeGen-projekt, datamodeller, regelmotor med enhetstester | Klar |
| 2. Skor | Mina skor, kamera/bildval, utklippning, redigering, borttagning | Klar |
| 3. Väder och Idag | Open-Meteo, plats/ort, cache, rekommendation, "Jag tar dessa", morgonnotis | Klar |
| 4. TestFlight | Ikon, version 0.1 (1), arkivering och uppladdning | – |

## Kom igång på en Mac

Kräver Xcode 16 eller senare och [XcodeGen](https://github.com/yonaskolb/XcodeGen).
Xcode-projektet genereras från `project.yml` och checkas inte in.

```sh
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig   # fyll i ditt team-id
xcodegen generate
open Skovader.xcodeproj
```

Kör `xcodegen generate` igen när filer har lagts till eller tagits bort.

## Tester

Alla tester (app + regelmotor) i simulatorn:

```sh
xcodebuild test -project Skovader.xcodeproj -scheme Skovader \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Byt `iPhone 16` mot en simulator som finns (`xcrun simctl list devices available`).

Bara regelmotorn – går snabbt och fungerar även i Linux:

```sh
cd Engine && swift test
# eller, utan Swift installerat (kör i Swifts Docker-image):
scripts/test-engine.sh
```

## Struktur

```
App/          Appens start och flikar
Models/       SwiftData: Shoe, WearLog
Services/     Väder (Open-Meteo, cache), plats och ort, bilder, notis,
              spara/ta bort skor, "Jag tar dessa"
Views/        Today, ShoeList, ShoeEditor, Settings, Onboarding
Resources/    Assets, Localizable.xcstrings, PrivacyInfo.xcprivacy
Engine/       Regelmotorn som eget Swift-paket (bara Foundation)
Tests/        Apptester (modeller, bilder, väder, cache, plats, val)
Config/       xcconfig: bundle-id och team
```

CI (`.github/workflows/ci.yml`) bygger och kör alla tester i iOS-simulatorn
vid varje push till `main`.

## Regelmotorn

`Engine/` är ett fristående Swift-paket utan beroenden till UI eller databas,
så det kan testas utan simulator. Appen översätter `Shoe` till
`ShoeProfile` och vädret till `DayWeather`, och får tillbaka ett förslag med
motivering i klartext.

- **Alla tal** (poäng, gränser, standardvärden per skotyp) finns i
  `Engine/Sources/SkovaderEngine/RecommendationConfig.swift`. Justera där
  efter testveckan.
- **Motiveringarna** byggs av mallar i
  `Engine/Sources/SkovaderEngine/Resources/sv.lproj/Localizable.strings`.
- **Testerna** i `Engine/Tests/SkovaderEngineTests/` täcker väderscenarier
  (sol, regn, snö, snöblandat, blåst, kyla), varje regel med gränsvärden,
  rotation, tomma lägen och motiveringstexterna.

## Väder

`WeatherService` är ett protokoll; `OpenMeteoWeatherService` hämtar timdata
för idag och imorgon. `WeatherStore` cachar prognosen i en timme och visar
senaste cachen offline. Regelmotorn sammanfattar timmarna 07–18 till
`DayWeather` (`DayWeather.summarizing`). Väderdata från
[Open-Meteo.com](https://open-meteo.com/) (CC BY 4.0).

## Integritet

Inga konton, ingen analys, inga tredjepartspaket. Bilder och skodata lämnar
aldrig telefonen. Till Open-Meteo skickas bara positionen avrundad till 2
decimaler (ca 1 km). Positionen översätts inte till ortnamn, så den skickas
inte till Apple. Vid manuell ort skickas bara söktexten till Apples
geokodning. App Privacy i App Store Connect: "Data Not Collected".
