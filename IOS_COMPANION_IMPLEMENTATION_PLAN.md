# ZSWatch: native iOS-companion med befintlig Flutter-app

Plan och fristående överlämning, 2026-10-12. Kan kopieras till en ny arbetstråd.

**Mac-överlämning:** Läs även `HANDOFF_TO_MAC.md` för exakta repositories, branches,
bibliotekspinnar och kopierbara kommandon. Användaren kopplar in samma debugger och
USB-rigg som på Linux. Debugger-reset och USB fungerar på Mac, men klockans
firmware-utvecklingsmiljö är **inte** installerad. Börja därför med installerad
firmware och befintliga USB/SMP-verktyg; blockera inte iOS-arbetet på en SDK-installation.
Om en firmwareändring verkligen behövs får agenten försöka sätta upp byggmiljön
på Mac själv eller be användaren om hjälp med den konkreta blockeraren.

## Mål

Gör motsvarande refaktorering för iOS som för Android: flytta ansvaret för BLE-anslutning, återanslutning och tidskritiska klockfunktioner till native kod, behåll befintligt Flutter/Dart-gränssnitt och återanvänd den delade Dart-koden för inspelningar, transkribering och lokal AI. Leverera en vanlig användbar iOS-app med befintliga produktfunktioner, verifierad på riktig iPhone och ZSWatch.

Målet är en följeslagarapp som klarar att användaren lämnar gränssnittet och att iOS suspenderar eller återstartar processen. Det är inte ett löfte om en permanent körande process. Flutter i sig är inte orsaken till iOS bakgrundsbegränsningar; även en helt native app omfattas av dem.

Denna plan ersätter den tidigare stegvisa strategin i `IOS_BLE_BACKGROUND_PLAN.md` för detta arbete. Android-planerna används som referenser för funktioner och erfarenheter, inte som instruktion att porta Androids livscykel eller foreground service till iOS.

## Ramar som redan är beslutade

- Behåll Flutter-UI:t och befintliga produktflöden. Bygg ingen separat native app eller separat Swift-version av AI-pipelinen.
- Gör refaktoreringen fullt ut. Ingen gammal BLE-ägare bakom en produktflagga, inget parallellt legacy-system och ingen omfattande migreringsapparat. Befintlig appdatabas får återställas vid uppgradering om det behövs; dokumentera konsekvensen. Detta innebär inte att inspelningar på klockan ska raderas.
- Återanvänd användarens modifierade Dart- och native-kod i `Flutter-nRF-Connect-Device-Manager` samt befintlig fllama-fork och transkriberingsintegration. Implementera inte eget SMP-protokoll.
- Normala voice memos och lokal transkribering/analys ingår. Experimentell voice chat/röstassistent stöds inte av klockan och ska förbli borttagen. Remote/hybrid AI och förbättring av redan existerande LLM-klassificering ingår inte.
- Hela appen ska fungera. Lägg inte huvuddelen av arbetet på inspelningar, HTTP eller en perifer felkombination medan andra funktioner saknas.
- Firmwarebuggar som blockerar arbetet får åtgärdas och flashas med befintliga verktyg. Håll ändringarna riktade.
- Inga åttatimmars- eller andra ersättande uthållighetstester. Användaren gör långtidstest senare.

## Utgångsläge och första kontroll

På nuvarande Linux-maskin ligger appen i `/home/jakkra/Documents/ZSWatchApp` och firmware i `/home/jakkra/Documents/ZSWatch`. På en Mac används motsvarande kloner.

Kontrollerat i koden vid planens skapande:

- iOS deployment target är 14.0 i Podfile, Xcode-projekt och Info.plist. Behåll detta initialt; dokumentera om ett verkligt bibliotekskrav kräver en ändring. Moderna API:er används med tillgänglighetskontroller.
- Info.plist har `bluetooth-central` och `fetch`. Dessa deklarationer bevisar inte att återställning fungerar.
- `zswatch_app/ios/Runner/AppDelegate.swift` registrerar Flutter-pluginer och en productivity-kanal knuten till UI-kontrollern. Där finns ingen motsvarande native companion-koordinator i startflödet.
- SMP-forkens iOS-del använder `iOSMcuManagerLibrary` 1.10.1 enligt podspec. Läs den faktiska Swift-koden och lokala modifieringarna innan integrationen bestäms.
- Firmware har redan `app/src/ble/ble_ancs.c`, `ble_ams.c` och `ble_cts.c` för iOS-relaterade funktioner. Bevara och använd dessa vägar där de är rätt.
- Android-referensen finns i `ANDROID_COMPANION_FINISH_PLAN.md`, `ANDROID_FEATURE_PARITY.md` och dess evidenslänkar. Överlämningsuppdatering: tidigare ocommittade röstkontroller/delad processor är nu commit `67976ef`, verifierad med 28 berörda Flutter-tester, native jobb-/policytester, analys och Android-releasebuild. Bibliotekens lokala diffar var enbart Dart-formatering och är nu committade på egna handoff-branches, pinnade i appcommit `4812a77`. Ingen ny fysisk acceptans av dessa röstkontroller påstås. Paritetsdokumentet innehåller fortfarande öppna punkter; commit/push betyder inte att de är lösta.

Första implementationstillfället: inventera Git-status och submoduler en gång, identifiera verifierad referens, bevara lokala ändringar och skapa en `codex/ios-companion`-branch från avsedd appversion. Kontrollera relevant historisk Flutter-kod före native-shell-förändringen `0a8f430`, så att Androids eventuella kvarvarande luckor inte blir iOS-specifikation. Gör ingen bred omgranskning av hela Android-arbetet.

## Plattformskontrakt

Core Bluetooth kan väcka appen för BLE-händelser och återställa registrerade centraler, anslutningar och prenumerationer. Swift-koordinatorn ska återbildas tidigt vid appstart med stabilt restoration-ID och hantera `willRestoreState`, återställda peripherals och deras delegates. Behandla bakgrundsanrop som korta arbetstillfällen; persistenta jobb får fortsätta senare. [Apple: Core Bluetooth background processing](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html).

Skilj mellan att lämna appen, systemsuspension, systemterminering och användarens uttryckliga force-quit. Planera för att force-quit kräver att användaren öppnar appen igen. Återställning förutsätter relevant väntande BLE-arbete och en utlösande händelse; det är ingen periodisk restart-tjänst. Apples äldre QA beskriver även begränsningar kring Bluetooth-avstängning och första upplåsning efter omstart. Kontrollera beteendet på de iOS-versioner som faktiskt testas; tolka inte en vanlig kallstart som bevis för force-quit. [Apple: restoration conditions](https://developer.apple.com/library/archive/qa/qa1962/_index.html).

Lång lokal AI kräver en separat körpolicy. `BGProcessingTask` är uppskjuten systemstyrd körning. På iOS 26+ kan `BGContinuedProcessingTask` användas för lämpliga arbeten som användaren startar i appens förgrund, exempelvis bearbetning eller tillbehörsuppdatering. Den är inte en generell startmekanism för ett BLE-event när appen redan ligger i bakgrunden. GPU-stöd kräver rätt capability och kontroll av tillgängliga resurser. [Apple: Finish tasks in the background](https://developer.apple.com/videos/play/wwdc2025/227/).

Automatisk inspelningshämtning och omedelbar lokal AI är därför två olika krav: säkra filen och jobbet först; kör AI när systemet tillåter, annars visa väntande status och erbjud bearbetning när appen öppnas. Lova inte omedelbar AI från en låst iPhone innan det är verifierat. Använd inte tyst ljud, ständig GPS eller konstgjorda BLE-paket för att hålla processen levande.

## Arkitektur

### Swift äger klocksessionen

Inför en native companion-koordinator som inte är beroende av en FlutterViewController eller Dart-isolate för att ta emot BLE-events. Den ansvarar för vald klocka, användarens Start/Stop, anslutning, service discovery, prenumerationer, återställning, kommandokö och korta bakgrundsuppgifter.

Håll en tydlig logisk ägare för varje klocksession. Granska hur Nordic-biblioteket äger sin transport och CoreBluetooth-objekt: återanvänd transport där det stöds, annars definiera en samordnad livscykel. Kräv inte en omöjlig SDK-integration bara för att tvinga fram exakt ett centralmanager-objekt. Däremot får två oberoende appflöden inte konkurrera om samma SMP-jobb eller ändra anslutningspolicy.

Persistenta inställningar och operationer ska överleva UI-omstart. Stop/Forget ska respekteras även av sena callbacks. Koppla svar till rätt klocka, session och operation så att ett gammalt HTTP-svar, filresultat eller AI-resultat inte levereras till en ny session av misstag. Använd iOS peripheral-identifierare och stabil produktidentitet där sådan finns, inte Android-MAC som universell nyckel.

### Dart äger presentation och delad bearbetning

Behåll befintliga skärmar, modeller och repositories. Återanvänd Androids command/snapshot-kontrakt där det passar, med uttryckliga plattformskapabiliteter. Flutter ansluter som klient till native tillstånd och startar inte den gamla BLE-ägaren på iOS.

Återanvänd `companion_voice_processor.dart` och dess rena beroenden. En headless FlutterEngine kan vara körmiljö för gemensam Dart-kod, men skapar ingen extra bakgrundsrättighet. Registrera nödvändiga pluginer/kanaler per engine och förhindra dubbla workers när UI och bakgrund överlappar. Flytta productivity-registrering från beroendet på UI-kontrollern där det behövs. Håll AI-motorer avlastade tills verkligt arbete finns.

### Lagring och återhämtning

Återanvänd befintliga filkvitton, jobbstatus, transkript/resultat och leveranskvittens som kontrakt. Skriv nedladdning till temporär fil, verifiera längd/integritet enligt tillgängligt protokoll och publicera först därefter. Avbrott får inte göra en partiell fil färdig eller radera originalet på klockan.

Välj en konsekvent databasåtkomst mellan Swift och Dart. Android-arbetet exponerade problem när olika SQLite-integrationer öppnade samma fil; kopiera inte den misslyckade konstruktionen till iOS. Bestäm skrivansvar, transaktioner och uppdatering av Flutter-vyer innan bakgrundsinsamlare kopplas på. Undvik ett nytt generellt lagringsramverk.

Verifiera filskydd och eventuell Keychain-åtkomst när telefonen är låst respektive ännu inte har låsts upp efter omstart. Använd lämpligt skydd per datatyp; gör inte all användardata oskyddad för att få bakgrundskoden att fungera. Loggar ska ge operationstillstånd utan att rutinmässigt dumpa privata inspelningar eller notifikationstexter.

## Funktionsinventering som ska stängas

Skapa `IOS_FEATURE_PARITY.md` med en rad per befintlig funktion och kolumner för tidigare beteende, ny implementation, plattformsskillnad och verifiering. Märk funktioner som inte stöds ärligt; tysta borttagningar räknas inte som färdigt.

| Område | Vad som ska ingå |
| --- | --- |
| Anslutning och hem | Onboarding, behörigheter, scan/val, parkoppling, sparad klocka, namn/byte/glöm, reconnect, Start/Stop, Restart Watch, alla sex befintliga feature-ingångar och sammanfattningar. |
| Notifikationer | Verifiera befintlig ANCS-väg i firmware, iOS delning av systemnotifikationer, reconnect och tillgängliga åtgärder. Porta inte Androids NotificationListenerService eller dess filtermöjligheter som om samma API fanns på iOS. ANCS levererar via telefonens tjänst till tillbehöret. [Apple ANCS](https://developer.apple.com/library/archive/documentation/CoreBluetooth/Reference/AppleNotificationCenterServiceSpecification/Introduction/Introduction.html). |
| Tid och media | Kontrollera befintlig CTS/AMS och appprotokoll; välj tydligt ansvar så de inte skickar motstridiga tids-/medieuppdateringar. Testa tid/tidszon och media metadata/play/pause/next med riktig iPhone. |
| GPS, väder och HTTP | Native hantering av klockans förfrågningar med tidsgräns, felstatus och rätt sessionskoppling. Testa genom att öppna Weather på klockan, vilket utlöser GPS och HTTP. Positionens ålder/precision ska hanteras; gammal position får inte presenteras som ny. Bakgrundsplats kräver en genomtänkt CoreLocation-policy och rätt behörighet, inte enbart en Info.plist-text. [Apple Core Location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background). |
| Hälsa och Analytics | Befintliga aktivitets-/puls-/stegvyer, Today/Week/Month, historik/retention, batterihistorik och anslutningshändelser. Insamling ska fungera utan Flutter-UI och bli synlig när det öppnas igen. Tidigare placeholders blir inte nya features i denna refaktorering. |
| Inspelningar | Lista/hämta/återuppta, uppspelning, sökning/filter/arkiv, lokal radering, kopiera/redigera transkript, transkribera separat, transkribera om, analysera om, batchåtgärder och automatisk transkribering med valfri analys enligt befintligt produktscope. Redan hämtade filer ska kunna bearbetas utan aktiv klockanslutning. |
| Lokal AI och åtgärder | Befintliga modellval/import/download/delete och relevanta inställningar. Gemensam transkribering/analys; inga nya klassificeringskrav. Behåll iOS kalender/reminder-flöden. Nuvarande timer/alarm i AppDelegate är lokala notifikationer, inte skapande i systemets Clock-app; UI och acceptans ska beskriva det korrekt. |
| Firmware och resurser | Vanliga filval, uppdatering/progress/fel/retry, korrekt bildtyp/slot och återanslutning efter omstart. Följ Nordic-bibliotekets stödda update-flöde. Otestade image-varianter får inte kallas stödda. |
| Övriga produktverktyg | Find-funktioner enligt befintligt iOS-stöd, watchface/bildval/crop/upload, filesystem, shell, sensorer, crash/logg-vyer och befintliga developer/settings-ingångar. Demo där relevant ska vara isolerad från riktiga klockkommandon. |

HTTP-reläet är en begränsad delfunktion, inte ett eget infrastrukturprojekt. Använd lämplig URLSession, avbryt eller avsluta rent vid förlorad körmöjlighet och återförsök endast operationer där det är korrekt. Undersök background URLSession för riktiga filöverföringar vid behov; anta inte att den ersätter ett interaktivt HTTP-relä med kort svarstid.

## Genomförande i ordning

### 1. Fastställ baseline och byggmiljö

- Läs relevanta repo-instruktioner, Git-status, ovanstående planer och berörda lokala bibliotek. Dokumentera vald baseline och inventera funktionerna innan UI-kopplingar tas bort.
- På Mac: verifiera Xcode/Flutter/CocoaPods, signing och en vanlig iOS-build. Registrera iPhone-modell, iOS-version och installerad firmware.
- På Linux kan kontrakt, Dart-kod och kodgranskning göras. iOS-kompilering kräver Apple-miljön; BLE-acceptans kräver en fysisk iPhone. Simulator eller Android-pass är inte ersättning.

**Klart:** reproducerbar buildmiljö eller tydligt avgränsad hårdvarublockering, samt en komplett första paritetslista.

### 2. Bygg den riktiga native BLE-grunden

- Implementera start, restoration, discovery, prenumerationer, återanslutning och explicit Stop i produktkoden.
- Koppla befintligt Flutter-anslutningsflöde till native. Stäng av den gamla ägaren som del av samma omläggning, utan användarflagga.
- Verifiera en verklig klockhändelse och ett svar med UI i bakgrunden, därefter reconnect och UI-återanslutning till native tillstånd. Testa även verklig restoration med identifierad metod och loggar; enbart Xcodes Stop-knapp bevisar inte systemåterställning.

**Klart:** grundflödet fungerar på iPhone och arkitekturen är belagd. Om en plattformsbegränsning hindrar ett krav: beskriv konsekvensen direkt, lägg inte dagar på att simulera en permanent process.

### 3. Stäng vardagsfunktionerna

- ANCS, CTS/tid, AMS/media, Find, GPS/väder/HTTP och native insamling till Health/Analytics.
- Återanvänd befintligt UI och verifiera alla feature-ingångar, inställningar och sparad-klocka-åtgärder.
- Bekräfta att skärmarna ser nytillkommen data efter en period utan Flutter-UI och att samma event inte dubbellagras.

**Klart:** kärnan fungerar i vanlig appanvändning, med korta riktade bakgrundstester.

### 4. Nordic SMP, firmware och större filer

- Integrera den modifierade iOS-SDK-vägen för shell, filesystem och uppdateringar under koordinatorns ansvar. Utgå från befintliga fixes; felsök inte om redan lösta cache-/förberedelseproblem från noll.
- Kontrollera firmwarelogik för connection parameters, buffers och SMP-aktivering. iOS bestämmer förhandlade BLE-värden; hårdkoda inte Androids MTU/intervall. Använd CoreBluetooth-värden för skrivstorlek och korrekt flödeskontroll för writes.
- Mät först kort representativ överföring med nyttolast som faktiskt kvitterats. Ange bytes/s, storlek och avbrott. Använd gammal iOS-app som jämförelse om tillgänglig. Historiskt krav var cirka 20 KB/s+, 17,6 KB/s accepterades på Nokia; senare Android-evidens anger cirka 41 KB/s. Detta är referenser, inte bevis för iPhone-prestanda.
- Få vanlig firmwareöverföring att fungera och gå tillräckligt snabbt innan stora filesystem-images testas. Verifiera verkligt installerad version och relevant integritet, inte bara progress 100 %.
- Testa ett avbrott/retry i relevant fas. Avbryt inte farliga flashfaser godtyckligt och återspela inte automatiskt reset-kommandon.

**Klart:** firmware, resurser och watchface/filer fungerar utan konkurrerande BLE-ägare. Bakgrundsfortsättning respektive säker paus/återstart är uppmätt och beskriven för stödda iOS-versioner.

### 5. Inspelningar och delad lokal AI

- Implementera native upptäckt/hämtning och hållbar kö först. Visa inspelningen även när AI saknas, är avstängd eller måste vänta.
- Koppla den gemensamma Dart-processorn till iOS körpolicy. Verifiera headless-kompatibilitet för faktiska pluginer, modellfiler, ljudavkodning och minnesåtgång. Separera BLE-callbacken från lång inferens.
- Återanvänd sparat transkript efter avbrott. Avsluta STT-resurser innan LLM laddas när det behövs. Hantera expiration/cancel och processbortfall utan att ett gammalt försök skriver över ett nyare resultat.
- Granska Metal/GPU-användning uttryckligen. Kör endast med tillåten exekvering; använd testad CPU-väg eller uppskjutet arbete där GPU inte kan användas. Avbrott mitt i inferens får innebära omstart av det steget; lova inte tokenvis återupptagning.
- Testa en riktig inspelning hela vägen till sparat transkript/resultat och klockans befintliga kvittens, plus ett återhämtningsfall. Behåll fulla inspelningskontroller från inventeringen.

**Klart:** lokal bearbetning fungerar och eventuell väntan på iOS-körtid är synlig och återhämtningsbar. Ingen Swift-kopia av AI-logiken eller remote-backend har införts.

### 6. Slutkontroll och leverans

- Stäng varje rad i paritetslistan. En saknad befintlig funktion är inte en plattformsbegränsning utan konkret belägg.
- Kör relevanta Swift-/Dart-tester, analys och signerad release-build. Kontrollera Android där gemensam kod har ändrats; kör inte om all oförändrad Android-hårdvaruacceptans.
- Gör ett kort sammanhängande pass i vanlig iPhone-app: onboarding, anslutning, lämna/lås/återöppna, kärnfunktioner, inspelning och relevanta uppdateringsflöden.
- Leverera commit, biblioteksversioner, installerbar artifact/signing-instruktion, firmwarekrav, tester och kända iOS-begränsningar. Ingen publicering till App Store ingår automatiskt.

## Kort fysisk testmatris

Registrera vad som faktiskt hände, med identifierad build och firmware. Återanvänd godkänd evidens när koden inte ändrats.

1. Vanlig första installation/behörigheter/parkoppling utan debugkommandon som krävs för att produkten ska fungera.
2. Förgrund → bakgrund → låst skärm → UI tillbaka; BLE-data sparas och visas korrekt.
3. Klockan lämnar räckvidd, kommer tillbaka och startas om: anslutning/prenumerationer och pågående arbeten återhämtas.
4. CoreBluetooth-restoration: skilj simulerad callback, injicerad processdöd och verkligt observerad OS-relaunch i rapporten. Dokumentera ej verifierade fall ärligt.
5. Användarens Stop/Forget och force-quit får rätt, skilda beteenden. Ingen oavsiktlig återstart efter explicit Stop.
6. Ett relevant fall med Bluetooth av/på, nätfel respektive nekad behörighet; tydlig status och användbar återhämtning. Första upplåsning efter telefonreboot provas separat från vanlig skärmlåsning.
7. AI-jobb nekas/avbryts av körpolicyn och kan fortsätta senare utan dataförlust eller dubbla åtgärder. En injicerad expiration testar koden men bevisar inte verklig schemaläggning.
8. Firmware- och filöverföring: hastighet, ett avbrott, återhämtning och faktisk slutstatus. Håll UI-/AI-arbete från att svälta BLE.

Lägg inte till en full matris av alla kombinationer. Nya tester ska besvara ett konkret fel eller en kvarvarande acceptansfråga.

## Klockverktyg och självständigt arbete

Läs `HANDOFF_TO_MAC.md` och `ZSWatchApp/scripts/companion_hil/README.md` för USB/SMP-bootstrapen, portägarskap och logginsamling. `scripts/companion_hil/watch_usb.py` samlar de tidigare temporära reset-/USB-proberna med explicita Mac/Linux-portar och probeval. Läs även `ZSWatch/website/docs/development/debugging.md`, `ZSWatch/app/pytest/README.md` och de publicerade verktygen `.agent_tools/flash_and_log.py` och `.agent_tools/serial_capture.py`. Historiska privata loggar och `/tmp`-filer behövs inte för grundflödet.

- Inventera rätt watch/probe/UART/USB-port före reset eller flash. Tidigare serienummer i dokumentationen är exempel från riggen, inte permanent identitet. På Mac ser portnamnen annorlunda ut.
- Klockans USB/SMP-port kan vara avstängd trots ansluten kabel. Förbered klienten före reset, öppna direkt när porten dyker upp, inom bootfönstret. Använd högst cirka 20 sekunder som praktisk gräns; vänta inte på användarens ungefärliga 24 sekunder.
- Följ README:s befintliga DTR/SMP-bootstrap och skicka ett verifierat kommando, exempelvis `app state`. Kontrollera att porten fortfarande fungerar efter bootfönstret. Om firmwareversionen behöver escape-sekvens eller ett särskilt keep-enabled-kommando, hämta den exakta sekvensen ur aktuell implementation/instruktion; gissa inte byte eller kommandon.
- Återanvänd `smpclient` för USB-testverktyg och Nordic för appens BLE-SMP. USB-prov bevisar inte BLE-prestanda. Blanda inte USB- och BLE-mätningar.
- Starta UART-loggning före ett händelseförlopp, normalt 115200 baud; använd RTT/GDB via debugger när relevant. Ha en läsare per port.
- Använd befintliga shell/UI-testkommandon för att öppna exempelvis Weather och kontrollera klockstatus. När ett kommando saknas, läs aktuell firmwarehjälp innan ett nytt debuggränssnitt övervägs.
- Vid verklig firmwarebugg: fånga felet, gör minsta riktade fix, bygg med rätt board/config, flasha vald probe och verifiera installerad artifact. `.agent_tools/flash_and_log.py` är en möjlig utgångspunkt men saknar explicit probeval; anpassa detta innan användning i en rigg med flera enheter.
- Nollställ inte klockan som rutinlösning på varje reconnectproblem. Städa egna fixtures och lämna användarens inspelningar och annat innehåll intakt.

Om iPhone eller Mac saknas: fortsätt med implementation, kontrakt, tester och granskning som kan göras på tillgänglig maskin. Redovisa sedan exakt vilka hårdvarupunkter som väntar; ersätt dem inte med upprepade fixtures och kalla inte BLE-delen färdig.

## Arbetsdisciplin och definition av färdigt

Arbeta i små avslutade produktsteg med relevanta commits, men leverera en enda normal arkitektur. Efter varje etapp: ange vad som fungerar, vilken evidens som finns och nästa blockerande punkt. Undvik nya ramverk, stora namnbyten och extra acceptanskrav utan konkret behov.

Färdigt betyder att den vanliga Flutter-appen använder native iOS-companion, att alla tidigare produktfunktioner är inventerade och implementerade eller har en uttryckligt beskriven faktisk plattformsbegränsning, att normal användning och korta återhämtningsfall är verifierade på riktig iPhone/klocka, och att lokal AI återanvänder Dart med ärlig iOS-körpolicy. Öppna implementationer och saknad fysisk evidens ska stå som kvarvarande arbete, inte döljas bakom ett procenttal.

## Kopierbar startinstruktion

Implementera iOS-companion enligt IOS_COMPANION_IMPLEMENTATION_PLAN.md. Behåll befintligt Flutter-UI och delad Dart-kod för lokal AI. Låt native Swift äga BLE och återställning, återanvänd våra modifierade Nordic-/AI-bibliotek och bygg inget eget SMP. Inventera samtliga befintliga funktioner före omläggningen. Arbeta i ordningen baseline/buildmiljö, native BLE/restoration, vardagsfunktioner, SMP/uppdateringar, inspelningar/lokal AI och kort slutacceptans. Bevara lokala ändringar och klockans originalfiler. Remote/hybrid AI, experimentell voice chat och långa uthållighetstester ingår inte. Följ planens iOS-begränsningar och redovisa hårdvaruverifiering ärligt. Börja med Git-status, relevant kod och tillgänglig Mac/iPhone; genomför sedan nästa möjliga steg utan att invänta ytterligare allmän bekräftelse.
