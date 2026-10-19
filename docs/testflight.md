# Skoväder till TestFlight

Bygget, signeringen och uppladdningen görs av GitHub Actions på en Mac hos
GitHub (`.github/workflows/testflight.yml`). Ingen egen Mac behövs.
Arbetsflödet skapar ett tillfälligt distributionscertifikat och en
App Store-profil via App Store Connect-API:t, laddar upp med
`xcodebuild -exportArchive` och tar sedan bort certifikatet och profilen igen.
Byggnumret blir automatiskt ett högre än det senast uppladdade.

## En gång

1. **Registrera bundle-id:**
   <https://developer.apple.com/account/resources/identifiers/add/bundleId>
   → *App IDs* → *App* → Description `Skovader`, Bundle ID *Explicit*
   `no.linus.skovader` → *Continue* → *Register*. Inga capabilities behövs.
2. **Skapa appen i App Store Connect:** *Appar* → **+** → *Ny app*:
   plattform iOS, namn `Skoväder` (är det upptaget, t.ex. `Skoväder – dagens skor`),
   primärt språk svenska, bundle-id `no.linus.skovader`, SKU `skovader`.
3. **API-nyckel för GitHub:**
   <https://appstoreconnect.apple.com/access/integrations/api> → *Team Keys* → **+**
   → namn `GitHub Skoväder`, roll **Admin** (krävs för att skapa certifikat och
   profiler) → *Generate* → ladda ned `.p8`-filen (går bara en gång). Notera
   *Key ID* och *Issuer ID* (överst på sidan).
4. **Hemligheter i GitHub:**
   <https://github.com/lingu78/skovader/settings/secrets/actions> →
   *New repository secret*, tre stycken:

   | Namn | Värde |
   |---|---|
   | `ASC_KEY_ID` | Key ID, t.ex. `ABC123DEFG` |
   | `ASC_ISSUER_ID` | Issuer ID, t.ex. `69a6de7e-…` |
   | `ASC_KEY_P8` | Hela innehållet i `.p8`-filen, inklusive raderna `-----BEGIN PRIVATE KEY-----` och `-----END PRIVATE KEY-----` |

   Hemligheterna syns aldrig i loggar eller i Git.

## Ladda upp en ny version

1. *Actions* → *TestFlight* → *Run workflow* (gren `main`). Tar 10–15 minuter.
2. Apple bearbetar bygget i 10–30 minuter.
3. App Store Connect → Skoväder → *TestFlight* → *Intern testning*: skapa en
   grupp, lägg till dig själv (och dottern) och välj bygget. Interna testare
   behöver ingen granskning från Apple. Testarna installerar via appen
   TestFlight på iPhone.

Versionsnumret (`MARKETING_VERSION`, nu 0.1) ändras i `project.yml`.

## Om något går fel

Felet står i loggen för steget som misslyckades:

- **Hittar ingen app med bundle-id** – steg 2 ovan saknas, eller bundle-id skiljer sig.
- **401/403 från App Store Connect** – fel Key ID/Issuer ID, eller nyckeln saknar rollen Admin.
- **Gräns för antal certifikat** – ta bort ett gammalt distributionscertifikat under
  *Certificates* på developer.apple.com (det som EAS använder för andra appar ska vara kvar).
