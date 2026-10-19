# Skoväder – kravspecifikation för iOS-app

Oct 19, 2026 · @Linus

## Sammanfattning och mål

Skoväder är en iPhone-app där användaren fotograferar sina skor, och varje morgon får en rekommendation om vilket par som passar dagens väder. Arbetsnamnet är Skoväder och kan bytas.

- **Användare:** en person med 3–15 par skor, i första hand Linus dotter och familjen. Ingen inloggning, all data lokalt på telefonen.
- **Språk:** svenska i gränssnittet, strängar i Localizable-fil så norska/engelska kan läggas till senare.
- **Testversionen (v0.1)** ska bevisa tre saker: att det går att lägga in ett skopar på under 30 sekunder, att rekommendationen känns rimlig minst 4 av 5 dagar, och att dottern faktiskt öppnar appen på morgonen under en testvecka.
- **Leverans:** en installerbar build via TestFlight, inte App Store-publicering.

## Användarflöden

Appen har tre flöden och två flikar: **Idag** (startsida) och **Mina skor**.

### A. Första start

1. Välkomstskärm med en mening om vad appen gör.
2. Fråga om platstillstånd ("När appen används"). Nekas det: låt användaren skriva in en ort istället.
3. Uppmaning att lägga till första skon.

### B. Lägga till sko

1. Tryck "+" under Mina skor.
2. Ta foto med kameran eller välj från bildbiblioteket.
3. Appen klipper automatiskt ut skon från bakgrunden (kan stängas av).
4. Välj typ (t.ex. sneakers, vinterkängor). Appen fyller i förslag på egenskaper utifrån typen.
5. Justera vid behov: vattentät ja/nej, värme, namn (t.ex. "Rosa Converse").
6. Spara.

### C. Dagens rekommendation

1. Öppna appen → Idag visar dagens väder (temperatur, nederbörd, ikon) för tiden 07–18.
2. Ett stort kort med rekommenderad sko: bild, namn och en kort motivering ("Det blir 4 grader och regn – ta dina vattentäta kängor").
3. Under det upp till två alternativ.
4. Knappen "Jag tar dessa" markerar skon som använd idag.
5. Har användaren inga skor som passar visas ett vänligt meddelande ("Inga av dina skor passar riktigt idag – närmast är …").

## Funktionella krav

Alla krav måste vara uppfyllda för v0.1. Acceptanskriteriet är det Claude Code testar mot.

| ID | Krav | Acceptanskriterium |
|---|---|---|
| F1 | Fotografera sko | Kamera och bildbibliotek fungerar; bilden sparas lokalt komprimerad (max 1024 px lång sida, JPEG/HEIC). |
| F2 | Automatisk utklippning | Skon klipps ut med Apples Vision-ramverk; om det misslyckas sparas originalbilden utan felmeddelande. |
| F3 | Skoegenskaper | Varje sko har: namn, typ, vattentät (ja/nej), värmenivå (1 lätt / 2 mellan / 3 varm), min- och maxtemperatur, aktiv (ja/nej). |
| F4 | Typförval | Val av typ fyller i standardvärden enligt tabellen i Rekommendationslogik; användaren kan ändra alla fält. |
| F5 | Lista och redigera | Mina skor visar ett rutnät med bilder; tryck öppnar redigering; svep eller meny tar bort (med bekräftelse). |
| F6 | Hämta väder | Prognos för aktuell plats hämtas vid appstart och vid neddragning; cachas i 1 timme; fungerar offline med senaste cache och visar "uppdaterad kl. HH:MM". |
| F7 | Rekommendation | Visar 1 huvudförslag + upp till 2 alternativ med motivering i klartext, enligt regelmotorn. |
| F8 | Rotation | "Jag tar dessa" sparar datum; en sko som använts de 2 senaste dagarna får lägre poäng (om likvärdiga alternativ finns). |
| F9 | Plats utan GPS | Om platstillstånd nekas kan användaren söka och spara en ort. |
| F10 | Tomt läge | 0 skor: Idag visar uppmaning att lägga till skor i stället för rekommendation. |
| F11 | Morgonnotis (valfri) | Användaren kan slå på en lokal notis vid vald tid (standard 07:00) med texten "Dags att välja skor – öppna Skoväder". Ingen server krävs. |

## Rekommendationslogik

Rekommendationen är en enkel, testbar regelmotor – ingen AI eller bildigenkänning i v0.1. Den ska ligga i en egen ren Swift-modul med enhetstester.

**Indata från vädret** (för tidsfönstret 07–18): känd temperatur ("feels like") min och max, total nederbörd i mm, nederbördstyp (regn/snö), max vindstyrka.

**Standardvärden per skotyp** (fylls i automatiskt, kan ändras):

| Typ | Vattentät | Värme | Min °C | Max °C |
|---|---|---|---|---|
| Sandaler | Nej | 1 | 18 | 40 |
| Sneakers / tygskor | Nej | 1 | 8 | 30 |
| Lädersneakers / finskor | Nej | 2 | 3 | 25 |
| Vattentäta sneakers / löparskor | Ja | 2 | 0 | 22 |
| Kängor / boots | Ja | 2 | -5 | 15 |
| Vinterkängor / fodrade | Ja | 3 | -30 | 5 |
| Gummistövlar | Ja | 1 | 0 | 20 |

**Steg 1 – filtrera** bort skor som är inaktiva, eller där dagens kända min-temp ligger mer än 5 °C under skons min, eller dagens max mer än 5 °C över skons max.

**Steg 2 – poängsätt** varje kvarvarande sko (start 100):

- Temperatur: −5 poäng per grad som dagen ligger utanför skons intervall.
- Regn ≥ 1 mm och skon inte vattentät: −40. Regn ≥ 5 mm och skon är gummistövel: +20.
- Snö och värmenivå < 3: −30. Snö och vinterkänga: +20.
- Torrt och vattentät sko med värme 3 när det är över 10 °C: −20 (undvik vinterkängor i onödan).
- Använd igår: −10. Använd både igår och i förrgår: −20.

**Steg 3 – resultat:** högst poäng blir huvudförslag, de två nästa blir alternativ. Om ingen sko har över 50 poäng visas "passar inte riktigt"-läget med den bästa ändå.

**Motivering:** genereras från mallar utifrån vilka regler som slog in, t.ex. "Det blir 4 grader och regn – dina [namn] håller fötterna torra."

Alla tal ovan ska ligga som konstanter i en konfigurationsfil så de kan justeras efter testveckan.

## Teknisk arkitektur

Nativ iOS-app utan backend: allt körs på telefonen och enda nätverksanropet är vädret.

| Del | Val | Kommentar |
|---|---|---|
| Språk och UI | Swift 5.9+, SwiftUI | |
| Minsta iOS | iOS 17 | Krävs för SwiftData och Visions utklippning. |
| Lagring | SwiftData | Bilder som filer i appens Documents-mapp; modellen sparar sökvägen. |
| Bild | PhotosPicker + kamera (UIImagePickerController-wrapper) | |
| Utklippning | Vision, VNGenerateForegroundInstanceMaskRequest | Resultat som PNG med transparent bakgrund. |
| Väder | Open-Meteo forecast-API | Gratis, ingen API-nyckel, timdata med apparent_temperature, precipitation, snowfall, wind_speed_10m. Kapslas i ett WeatherService-protokoll så det kan bytas mot Apple WeatherKit eller MET Norway senare. |
| Plats | CoreLocation, "When In Use" | Geokodning av ort via CLGeocoder vid manuell ort. |
| Notiser | UserNotifications, lokala | |
| Beroenden | Inga tredjepartspaket | Håller bygget enkelt. |
| Projekt | Xcode-projekt genererat med XcodeGen (project.yml) | Gör projektet lätt för Claude Code att skapa och ändra som text. |
| Tester | XCTest/Swift Testing för regelmotorn, minst 15 väderscenarier | |

**Mappstruktur:** App/, Models/ (Shoe, WearLog), Services/ (WeatherService, LocationService, ImageService), Engine/ (RecommendationEngine + konfig), Views/ (Today, ShoeList, ShoeEditor, Onboarding), Tests/.

**Info.plist-texter (svenska):** NSCameraUsageDescription, NSPhotoLibraryUsageDescription, NSLocationWhenInUseUsageDescription.

**Utseende:** stora bilder på skorna, mjuka färger, fungerar i ljust och mörkt läge, stöd för Dynamic Type. En enkel appikon (sko + sol/moln) behövs för TestFlight.

## Integritet och säkerhet

Eftersom en av användarna är ett barn samlar appen in så lite som möjligt och skickar ingenting om användaren någonstans.

- Inga konton, ingen analys, ingen reklam, inga tredjepartsbibliotek.
- Bilder och skodata lämnar aldrig telefonen.
- Till vädertjänsten skickas bara koordinater avrundade till 2 decimaler (cirka 1 km noggrannhet).
- App Privacy-uppgifterna i App Store Connect kan därför anges som "Data Not Collected".

## Utanför scope för v0.1

Dessa saker byggs inte nu, men arkitekturen ska inte stänga dörren för dem.

- Automatisk igenkänning av skotyp från bilden (AI).
- Klädrekommendationer utöver skor.
- Flera profiler (hela familjen) och synk via iCloud.
- Widget på hemskärmen och Apple Watch.
- Kalenderkoppling (t.ex. "idrott idag → gympaskor").
- Publicering på App Store och Android-version.

## Leverans till TestFlight

Claude Code kan skriva, bygga och ladda upp appen, men bara om den körs på en Mac med Xcode och du först har gjort kontodelen hos Apple. iOS-appar kan inte byggas i Linux-miljö, så Claude Code i molnet räcker inte för själva bygget och uppladdningen.

**Det här måste du göra själv (en gång):**

- [ ] Ha tillgång till en Mac med senaste Xcode installerat.
- [ ] Gå med i Apple Developer Program (kostar en årsavgift, kontrollera aktuellt pris på developer.apple.com). Som privatperson tar det oftast 1–2 dagar.
- [ ] Logga in med ditt Apple-konto i Xcode (Settings → Accounts) så signering fungerar automatiskt.
- [ ] Skapa appen i App Store Connect: namn, bundle-id (t.ex. no.linus.skovader), språk svenska.
- [ ] Skapa en App Store Connect API-nyckel (Users and Access → Integrations) och spara .p8-filen lokalt, så Claude Code kan ladda upp utan att du klickar i Xcode.
- [ ] Lägg till dig själv och dottern som interna testare i TestFlight. Dottern behöver TestFlight-appen och ett Apple-konto (familjedelning fungerar).
- [ ] Besvara exportfrågan om kryptering (appen använder bara standard-HTTPS).

**Det här gör Claude Code:**

- Genererar projektet, skriver all kod, tester, ikon och Info.plist-texter.
- Kör tester och bygger i iOS-simulatorn.
- Sätter versionsnummer och byggnummer, arkiverar och laddar upp till App Store Connect med `xcodebuild -exportArchive` och API-nyckeln.
- Skriver en kort README med hur man bygger och laddar upp en ny version.

Efter uppladdning tar Apples automatiska bearbetning normalt 10–30 minuter innan bygget dyker upp för interna testare. Interna testare kräver ingen granskning från Apple.

## Byggordning och instruktioner till Claude Code

Bygg i fyra etapper och stanna efter varje etapp för en kort avstämning med Linus.

1. **Grund:** XcodeGen-projekt, datamodeller, regelmotor med enhetstester (minst 15 scenarier: varm sol, kyligt regn, snö, blåst, inga skor, alla skor använda nyligen). Allt grönt innan nästa steg.
2. **Skor:** Mina skor-fliken, kamera/bildval, utklippning, redigering och borttagning.
3. **Väder och Idag:** WeatherService mot Open-Meteo, plats och manuell ort, cache, Idag-vyn med rekommendation och "Jag tar dessa", morgonnotis.
4. **TestFlight:** ikon, versionsnummer 0.1 (build 1), arkivering och uppladdning enligt avsnittet ovan.

**Arbetsregler:**

- Fråga hellre än gissa om ett krav är oklart; föreslå då ett standardval.
- Lägg inte till funktioner från Utanför scope.
- Inga hemligheter i Git: API-nyckelns sökväg och ID läses från miljövariabler.
- Commit efter varje etapp med tydligt meddelande.

**Klart när:** bygget finns i TestFlight, går att installera på en riktig iPhone, och flödena A–C fungerar utan krasch.
