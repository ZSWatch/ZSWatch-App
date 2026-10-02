# Review av companion-planen

Datum: 2026-10-02. Granskad version: [COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md](/home/jakkra/Documents/ZSWatchApp/COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md), 653 rader. Originalplanen har inte ändrats i denna review.

**Status efter uppföljning:** fynden har nu arbetats in i planen. Användarens prioritering gäller: companion-arkitektur och normala bakgrundsflöden först, processavbrott under väntande iOS-jobb som separat recovery-fall och HTTP-kontraktet som en mindre sidoändring. Prioriteter och radnummer nedan återger den ursprungliga reviewn; den reviderade planen styr genomförandet.

## Bedömning

Riktningen är välgrundad: behåll Flutter-gränssnittet, flytta ägarskap av kritisk bakgrundskommunikation från UI-livscykeln och gör recordings/jobben beständiga. Att skriva om gränssnittet native skulle inte undanröja operativsystemens exekveringsregler.

Planen är användbar för labbsetup och prototyper, men bör revideras innan arkitektur och releasegrind låses. Tre P1-fynd gäller automatisk framdrift, verklig nätåtkomst i bakgrunden och HTTP-kontraktet. Ett P2-fynd gäller risken för missvisande långtidstester.

Granskningen omfattar hela planen, officiell plattformsdokumentation och riktade kodkontroller av HTTP och recording-sync. Ingen bred kodbasgranskning eller ny hårdvarutestserie har gjorts. P1 betyder att frågan behöver lösas innan den berörda arkitektur-/acceptansgrinden; det hindrar inte förberedelsearbete.

## R1 — [P1] Beständig remote-kö saknar en konkret väg till automatisk resultatleverans på iOS

**Plats:** [remote körning, rad 222](/home/jakkra/Documents/ZSWatchApp/COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md:222), [iOS-prototypgrinden, rad 619](/home/jakkra/Documents/ZSWatchApp/COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md:619).

Planen sparar serverjobb-ID och säger att push kan hjälpa och polling kan ske vid tillåtna wakeups/foreground. Det beskriver hur data överlever, men lämnar händelsen som driver nästa steg olöst.

Ett konkret fall är att inspelningen laddas upp, servern accepterar jobbet och iOS suspenderar appen. Servern blir sedan klar medan klockan fortfarande är ansluten men tyst. En SQLite-rad, en redan etablerad BLE-anslutning och ett serverjobb ger inte i sig en ny callback till appen. Resultatet kan därför förbli på servern tills en annan händelse eller appöppning råkar inträffa. Om resultatet redan har sparats kan samma problem finnas mellan outbox och faktisk watch-leverans.

Detta är en arkitekturslutsats från den föreslagna kedjan, inte ett uppmätt fel i en redan implementerad lösning. Apple anger att silent/background push inte har garanterad leverans och kan fördröjas eller strypas. Därför räcker inte heller “lägg till push” som enda lösning. [Apple: background updates](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app).

**Ändring som behövs:** ange för varje väntande fas vad som driver den vidare, hur retry schemaläggs och vilket användarlöfte som gäller. Välj och prova en kombination av stödda mekanismer: exempelvis servernotifiering, OS-hanterad överföring och riktiga resultatförfrågningar från klockan medan ett känt jobb väntar. Sådana förfrågningar ska ha avgränsad retry-/batteripolicy och inte vara en allmän keepalive för att hålla appen igång. Där plattformen inte kan ge en leveransfrist måste produktens fördröjda beteende beslutas uttryckligen.

**Verifiering:** låt servern bli klar först efter att telefonappen gått ur exekvering. Håll klockan ansluten, öppna inte appen och injicera inga orelaterade events. Bevisa färdigt resultat på klockan eller dokumentera det beslutade vänteläget. Prova även utebliven push. Flytta denna minimala submit→result→watch-kedja till den tidiga iOS-prototypgrinden; spara inte hela genomförbarhetsfrågan till etapp 4.

## R2 — [P1] Android-grinden kan godkänna levande BLE trots att HTTP inte fungerar i Doze

**Plats:** [Android-ägarskap, rad 124](/home/jakkra/Documents/ZSWatchApp/COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md:124), [BG-05, rad 561](/home/jakkra/Documents/ZSWatchApp/COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md:561).

Planen fokuserar på companion-service och foreground service, men preciserar inte vilken konfiguration som ger nätåtkomst när telefonen är i Doze. Samtidigt tillåter BG-05 “funktion/resultat eller definierad väntan”. En implementation kan då ha fungerande BLE och ett korrekt fel-/pending-svar men ändå inte kunna hämta den information som användaren begär från klockan.

Att appen lever är inte tillräckligt bevis för tillgänglig nätåtkomst. Android dokumenterar att Doze suspenderar nätåtkomst och skjuter upp jobb, med särskilda undantag. [Android: Doze](https://developer.android.com/training/monitoring-device-state/doze-standby).

**Ändring som behövs:** gör nätåtkomst till en separat tidig verifieringspunkt. Specificera CDM-association, relevanta companion-/databehörigheter och den faktiska power-exemption som används på respektive version; kontrollera resulterande OS-state. Utred fallback om association eller undantag saknas. Detta är inte en rekommendation att alltid kräva ett manuellt batteriundantag — först ska rätt companion-flöde och dess faktiska effekt provas.

Skilj i acceptanskraven mellan:

- Färskt HTTP-svar inom beslutad deadline under stödda bakgrundsvillkor.
- Avsiktligt tillåten cache med synlig ålder.
- Kontrollerat fel när nätet eller behörighet verkligen saknas.
- Fördröjt arbete som produkten uttryckligen accepterat.

Ett kontrollerat timeout-/pending-svar är felhantering, inte automatiskt PASS för ett krav på färsk information.

**Verifiering:** faktisk fysisk telefon, verifierat Doze-state, snabb kontrollerad server, klockinitierad request och mätt färskt svar på klockan. Registrera association/exemption/datapolicy. Kör även utan den förväntade behörigheten så fallbackens produktbeteende blir känt.

## R3 — [P1] Planens befintliga HTTP-fallback är inte ett fungerande slutkontrakt idag

**Plats:** [HTTP-kontrakt/fallback, rad 162](/home/jakkra/Documents/ZSWatchApp/COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md:162).

Den riktade kodkontrollen visar:

- Klockans HTTP-klient har **10 sekunders timeout**: [ble_http.c:14](/home/jakkra/Documents/ZSWatch/app/src/ble/ble_http.c:14).
- Appens HTTP-klient har **30 sekunders timeout**: [http_relay_service.dart:41](/home/jakkra/Documents/ZSWatchApp/zswatch_app/lib/services/http/http_relay_service.dart:41).
- Ett svar med `err` stoppar watch-timeouten och sätter `request_pending=false`, men loggar bara felet utan att anropa callbacken: [ble_http.c:45](/home/jakkra/Documents/ZSWatch/app/src/ble/ble_http.c:45). Även ett tomt svar saknar terminal callback i denna väg.
- Responsvägen kontrollerar ID men inte att requesten fortfarande väntar. Ett sent svar med samma ID kan därför anropa callback efter att timeout redan levererats.

Till exempel når telefonens HTTP 500-fel inte väderappens felhantering, eftersom den ligger i callbacken: [weather_app.c:130](/home/jakkra/Documents/ZSWatch/app/src/applications/weather/weather_app.c:130). Detta är befintliga kodgap, inte fel introducerade av planen. De gör däremot formuleringen att falla tillbaka till “befintligt timeout/error-svar” otillräcklig.

**Ändring som behövs:** lägg in ett litet obligatoriskt arbete med HTTP-slutkontraktet före native-portning/acceptans. Bestäm sammanhängande deadline för telefon och klocka med marginal för wakeup, nät och BLE-svar. Ge varje accepterad request exakt ett terminalt utfall: success, error, timeout eller uttrycklig cancellation. Sena och dubbla svar ska ignoreras enligt requestens livscykel. Om 10 sekunder är för kort för avsett bakgrundsbeteende behövs ett beslutat och kompatibelt nytt kontrakt; en längre telefon-timeout löser inte detta.

**Verifiering:** felsvar och tomt svar före watch-timeout, lyckat svar efter watch-timeout, dubblettsvar och normal framgång. Assertions ska kontrollera den verkliga watch-konsumentens callback/state, inte endast transportlogg eller svarspaket.

## R4 — [P2] Långtidstester behöver ett separat tyst läge och mätning från första användarhändelsen

**Plats:** [SOAK-01, rad 588](/home/jakkra/Documents/ZSWatchApp/COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md:588), [latensmål, rad 604](/home/jakkra/Documents/ZSWatchApp/COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md:604).

SOAK-01 använder återkommande watch-requests/notifs/recordings. Det provar belastning och kontinuitet, men återkommande riktiga events kan också ge appen täta exekveringstillfällen. Det bevisar inte att den första requesten efter flera timmars tystnad fungerar. SOAK-02 förbjuder manuell appöppning men specificerar inte en sådan tyst period.

Dessutom börjar latensmålen när länken redan är `protocol-ready` eller när presence redan observerats. Misslyckad upptäckt eller wakeup riskerar då att falla utanför just dessa mätetal. Båda mätningarna är användbara diagnostiskt, men måste kompletteras med användarens hela väntetid och alla misslyckade försök.

**Ändring som behövs:** lägg till ett scenario med exempelvis 2–8 timmars tystnad, låst och urkopplad telefon, ingen periodisk testtrafik och ingen aktiv appinstrumentering som håller processen prioriterad. Därefter initierar klockan ett verkligt HTTP-anrop eller avslutar en recording. Behåll ett separat belastningsprov med återkommande trafik.

**Verifiering:** mät från watch-händelsen till verkligt svar/varaktig mottagning. Redovisa samtliga försök, andel fullföljda inom deadline, förlorade/missade händelser och latency för lyckade försök. Efter ett misslyckande samlas bevis innan harness gör en reset eller startar appen. Fortsätt även mäta protocol-ready/presence-deltan för felsökning.

## Det som kan behållas

- Flutter som UI med ett tydligt livscykeloberoende companion-kontrakt.
- Säker file/DB-commit före watch-delete, recovery och beständig result-outbox.
- Separata val för lokal STT, remote STT/ljudmodell och lokal/remote text-LLM.
- Skillnaden mellan OS-processdöd, task removal och användarens Force Stop/force-quit.
- ASK-spåret för iOS 26 är inte ett uppenbart sakfel i planen. Det har stöd i Apples aktuella vägledning, men är fortfarande en hårdvaruprototypfråga. [Apple DTS](https://developer.apple.com/forums/thread/840468).
- Planens varning för implicit recover/reset i befintliga pytest-fixtures och kravet på matchande ELF vid crashanalys.

Jag skulle också låta prototyperna avgöra hur mycket Dart som behöver flyttas, innan en bred DB-migrering/native-portning bestäms. Det är ett omfattningsråd, inte ett separat blockerande fynd.

## Föreslagen revidering i ordning

1. Skärp funktionskrav och pass/fail för färsk HTTP samt automatisk AI-resultatleverans.
2. Lägg till Androids nätåtkomstgrind och iOS hela remote-resultatkedja i de tidiga prototyperna.
3. Lägg till HTTP-slutkontraktet som ett konkret firmware/app-arbetspaket.
4. Komplettera testmatrisen med tyst långtidsprov och end-to-end-mätetal.

Därefter är planen en rimlig grund för genomförande i etapper. De osäkra plattformsantagandena ska avgöras med de små prototyperna innan större migrering påbörjas.
