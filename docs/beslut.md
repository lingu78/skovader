# Beslut och standardval

Där kravspecen ([kravspec.md](kravspec.md)) lämnar något öppet har ett
standardval gjorts. Linus har överlåtit besluten till Claude (19 okt 2026);
valen nedan gäller tills testveckan visar något annat. Ändras något justeras
konstanten i `Engine/Sources/SkovaderEngine/RecommendationConfig.swift`.

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

## Etapp 2 – skor

| # | Fråga | Beslut |
|---|---|---|
| 19 | När väljs bilden? | I redigeraren: "+" öppnar "Ny sko" med knapparna Ta foto / Välj från bildbiblioteket. Allt sker i en vy, så det går snabbt och inga ark öppnas efter varandra. En sko kan sparas utan bild. |
| 20 | Filformat | Utklippta bilder sparas som PNG (transparent bakgrund), övriga som JPEG med kvalitet 0,8. Längsta sidan högst 1024 px. HEIC används inte – JPEG räcker och PNG behövs för transparensen. |
| 21 | Stänga av utklippning | Reglaget "Klipp ut skon automatiskt" i redigeraren. Valet kommer ihåg till nästa sko. Misslyckas utklippningen (t.ex. i simulatorn) sparas originalet utan meddelande. |
| 22 | Ta bort | Långtryck på en sko → Ta bort → bekräftelse, eller knappen Ta bort sko i redigeraren. Svep passar inte i ett rutnät. Bildfilen och historiken tas bort samtidigt. |
| 23 | Byta typ på befintlig sko | Fyller i typens standardvärden igen (F4). Namn och aktiv behålls. |
| 24 | Temperaturintervall i redigeraren | Lägsta −40 till 40 °C, högsta −40 till 45 °C. Lägsta kan inte bli högre än högsta. |
| 25 | Namn saknas | Typens namn visas i stället, t.ex. "Gummistövlar". |

## Etapp 3 – väder och Idag

| # | Fråga | Beslut |
|---|---|---|
| 26 | Exakt tidsfönster | Temperatur och vind från timmarna 07–18. Nederbörd från timmarna 08–18, eftersom Open-Meteo anger nederbörden för timmen före – tillsammans 07:00–18:00. Timmarna ligger i `RecommendationConfig`. |
| 27 | Regn eller snö? | Andelen snö av nederbördens vattenmängd: minst 75 % = snö, högst 25 % = regn, däremellan snöblandat (`sleetMinimumShare`). 7 cm snö räknas som 10 mm vatten. |
| 28 | Cache | En timme. Neddragning hämtar alltid. Ny plats eller ny dag hämtar också. Prognosen gäller idag och imorgon, så gårdagskvällens cache räcker offline nästa morgon. Sparas i Application Support. |
| 29 | När frågar appen om plats? | Bara när användaren trycker på en knapp: i introduktionen, på kortet "Var är du?" under Idag eller i Inställningar. Aldrig av sig själv. |
| 30 | Platsens namn | "Din plats" när telefonens position används. Ingen omvänd geokodning, så positionen skickas inte till Apple. Vid vald ort visas ortens namn. |
| 31 | "Jag tar dessa" flera gånger samma dag | Senaste valet gäller; tidigare val samma dag ersätts. Ett par som inte föreslogs men valts tidigare visas som "Idag har du valt …". |
| 32 | Idag på kvällen | Visar fortfarande dagens 07–18. |
| 33 | Morgonnotis | Text enligt kravet, upprepas varje dag på vald tid (standard 07:00). Tillstånd frågas när reglaget slås på; nekas det stängs reglaget av med en förklaring. |
| 34 | Källhänvisning | Open-Meteos data är CC BY 4.0, så Idag och Inställningar länkar till Open-Meteo.com. |
| 35 | Ortsökning | CLGeocoder enligt kravspecen. Kan bytas mot MapKits geokodning om Apple tar bort CLGeocoder. |
| 36 | Väderikon | Nederbörd (från 1 mm) och blåst (från 10 m/s) först, annars den vanligaste himlen enligt timmarnas WMO-koder. |

## Etapp 4 – TestFlight

| # | Fråga | Beslut |
|---|---|---|
| 37 | Bygge utan egen Mac | GitHub Actions på `macos-latest` arkiverar och laddar upp med `xcodebuild -exportArchive` och API-nyckeln (`.github/workflows/testflight.yml`). |
| 38 | Signering utan registrerad iPhone | Automatisk signering kräver en registrerad enhet. Arbetsflödet skapar i stället ett tillfälligt distributionscertifikat och en App Store-profil via App Store Connect-API:t, signerar manuellt och tar bort båda efteråt. Uppladdade byggen påverkas inte. |
| 39 | Byggnummer | Ett högre än det högsta som redan finns i App Store Connect; första bygget blir 1. Versionen (0.1) står i `project.yml`. |
| 40 | Egen app i App Store Connect | Skoväder får en egen app (`no.linus.skovader`). Den befintliga testappen (Rastcamp) används inte, eftersom ett bygge bara kan laddas upp till appen med samma bundle-id. |
| 41 | API-nyckelns roll | Admin, eftersom nyckeln skapar certifikat och profiler. Nyckeln ligger bara som hemlighet i GitHub. |
| 42 | Appikon | Sko under sol och moln i mjuka färger, 1024 px utan genomskinlighet. Källan är `design/AppIcon.svg`. |

## Utveckling

| # | Fråga | Beslut |
|---|---|---|
| 18 | Hur verifieras appkoden utan Mac? | GitHub Actions (`.github/workflows/ci.yml`) bygger och testar i iOS-simulatorn på en macOS-runner vid varje push till `main` och varje PR. Regelmotorn testas dessutom i Linux. macOS-minuter räknas tio gånger mot kontots kvot för privata repon. |
