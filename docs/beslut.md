# Beslut och standardval

Där kravspecen ([kravspec.md](kravspec.md)) lämnar något öppet har ett
standardval gjorts. Varje punkt ska stämmas av med Linus; ändras något
justeras konstanten i `Engine/Sources/SkovaderEngine/RecommendationConfig.swift`.

## Etapp 1 – regelmotorn

| # | Fråga | Standardval |
|---|---|---|
| 1 | Vad är "torrt"? | Mindre än 1 mm nederbörd 07–18 (samma gräns som regnregeln). |
| 2 | Hur mycket snö krävs för snöreglerna? | Minst 1 mm vattenmängd snö 07–18 (`snowThresholdMM`). Ett par flingor räknas inte. |
| 3 | Snöblandat regn? | Räknas som både regn och snö, så alla regn- och snöregler gäller. Kravspecen nämner bara regn/snö. |
| 4 | "Över 10 °C" i regeln mot vinterkängor | Dagens högsta kända temperatur 07–18 är över 10. |
| 5 | Vind | Ändrar inte poängen – den finns redan i den kända temperaturen. Nämns i motiveringen ("blåsigt") från 10 m/s. |
| 6 | Rotation | Bara igår (−10) och igår + i förrgår (−20) ger avdrag, precis som i tabellen. Bara i förrgår ger inget avdrag. Det man valt idag påverkar inte dagens förslag. |
| 7 | Lika poäng | 1) skon vars intervall ligger närmast dagens temperatur, 2) den som inte använts på längst tid, 3) namn. |
| 8 | Alla skor bortfiltrerade | "Passar inte riktigt"-läget med den sko som har högst poäng (utan filter). |
| 9 | Exakt 50 poäng | Räknas som "passar inte riktigt" (kravet säger "över 50"). |
| 10 | Motiveringens temperatur | Avrundad känd temperatur. Ett tal om min och max skiljer högst 3 grader, annars intervall ("2 till 9 grader"). |
| 11 | Texter | Motiveringar och typnamn ligger i motorns `sv.lproj/Localizable.strings`, UI-texter i appens `Localizable.xcstrings`. Norska/engelska läggs till bredvid. |

## Etapp 1 – appen

| # | Fråga | Standardval |
|---|---|---|
| 12 | Bildens sökväg | Modellen sparar filnamnet relativt Documents-mappen, inte den absoluta sökvägen (som kan ändras mellan installationer). |
| 13 | Datamodell och framtida iCloud | Inga unika index och standardvärden på alla fält, vilket iCloud-synk med SwiftData kräver. Ingen synk byggs nu. |
| 14 | Exportfrågan om kryptering | `ITSAppUsesNonExemptEncryption = NO` i Info.plist, så App Store Connect inte frågar vid varje build. |
| 15 | Bundle-id och team | `no.linus.skovader` som standard. Team-id och eget bundle-id läggs i `Config/Local.xcconfig` (checkas inte in). |
| 16 | Enheter och orientering | Bara iPhone, stående läge. |
| 17 | Integritetsmanifest | `PrivacyInfo.xcprivacy` deklarerar ingen spårning, ingen datainsamling och UserDefaults (CA92.1) för appens egna inställningar. |
