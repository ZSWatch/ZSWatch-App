# Voice-jobb och recovery: kontrakt v1 för telefonfria prototyper

2026-10-02. Detta är ett körbart referenskontrakt för etapp 1 och underlag för
etapp 2–4 i [implementationsplanen](COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md).
Det är inte inkopplat i produktionsappen. Referensimplementationen använder Python
och separata SQLite-filer; Flutter/native-adaptrar ska senare kunna köra samma
JSON-fixtures. Ingen schemaändring i appens Drift-databas har gjorts.

## Identitet och backendval

[`job-v1.json`](scripts/companion_hil/remote_jobs/fixtures/job-v1.json) innehåller
watch-ID, recording-ID, input-SHA-256, backend (`local`/`remote`), provider,
modell, pipeline-revision, generation och uttryckligt uploadval.
Jobbnyckeln är SHA-256 av UTF-8 JSON med sorterade nycklar, utan extra whitespace
och med Unicode bevarad. V1 tillåter bara strängar, bool och heltal i denna
envelope; ingen Unicode-normalisering görs. Golden-nycklar finns i
[`recovery-v1.json`](scripts/companion_hil/remote_jobs/fixtures/recovery-v1.json).

Samma input/konfiguration/generation ger samma jobbnyckel vid varje retry.
Ändrad input eller backend kräver en ny generation. En ny generation registreras
atomärt med att äldre, ännu inte kvitterade generationer av samma recording
avbryts och deras väntande outbox tas ur leveranskön. Redan levererat resultat
kan inte dras tillbaka av denna operation.

Remote kräver `upload_authorized=true`. Lokal bearbetning använder samma
resultat/outbox-kontrakt, utan remote-ID; remote-drivern vägrar lokala jobb.
En retry byter aldrig backend eller samtycke automatiskt. Credentials ligger
utanför envelope, jobbnyckel, loggar och fixtures. Produktionssamtycke och
återkallat samtycke måste kontrolleras före varje faktisk upload, inte bara vid
skapandet av jobbet.

Input-hashen motsvarar den syntetiska filen från USB-provet. Servern tar bara
emot metadata och ger ett fast syntetiskt resultat; den verifierar inte ljud,
gör ingen filupload och kör ingen STT/LLM. Filpath, verklig hashverifiering,
beständig ljudmottagning och file/DB-reconciliation tillkommer i receipt-adaptern.

## Jobbtillstånd och ownership

| Tillstånd | Beständig betydelse | Nästa tillåtna steg |
|---|---|---|
| `ready` | Input-identitet och backendval registrerade. | Claim och submit, eller lokal bearbetning. |
| `waiting_remote` | Server-ID sparat. | Status/resultat vid explicit trigger och efter sparad deadline. |
| `result_ready` | Resultat och outbox finns i samma commit. | Leverans när rätt watch är protocol-ready. |
| `delivered` | Matchande kvittens på mottagning sparad. | Ingen automatisk replay. |
| `blocked` | Credentials/authorization kräver åtgärd. | Explicit credential-refresh före återupptagning. |
| `failed` | Permanent fel eller retry-budget förbrukad. | Synligt fel; uttrycklig omkörning i ny generation. |
| `cancelled` | Lokala callbacks och väntande leverans avvisas. | Ingen automatisk återstart. |

Claim sker i SQLite-transaktion med lease-deadline och stigande fencing-token.
Bara en worker får claim samtidigt. Varje accepterat svar/commit kontrollerar
att token fortfarande ägs av rätt försök, leasen gäller och jobbet är aktivt.
Efter processdöd kan nästa worker ta över när leasen löpt ut; äldre callbacks
avvisas även om det nya försöket fortfarande arbetar.

Testdrivern har 30 s lease, 10 s mellan statuskontroller, maximalt fem misslyckade
försök, begränsad transport-backoff och respekt för `Retry-After`. Ett normalt
`running`-svar förbrukar inte felbudgeten. Dessa är fixturevärden, inte godkända
produktgränser. Jobben lagrar deadlines som UTC epoch-sekunder; testklockan
injiceras. En riktig runtime behöver hantera klockjusteringar och längre
OS-transfers genom beständiga transfer-ID:n och kontrollerad lease-förnyelse.

`advance()` får bara köras efter en uttrycklig trigger: foreground-start,
verkligt watch-event, OS-transfer-callback eller en OS-tillåten worker.
Referensdrivern startar inga timers eller workers. Dessa namn bevisar inte att
plattformen faktiskt ger exekvering; iOS-triggern under normal suspension måste
fortfarande verifieras på iPhone. Att servern blir klar ändrar inte lokalt state
innan en trigger behandlats.

## Avbrottsgränser

| Avbrott | Recovery-kontrakt |
|---|---|
| Serveraccept före lokalt sparat server-ID | Submit igen med exakt samma idempotency key återförenas med samma serverjobb. |
| Sparat server-ID; processen/UI försvinner | Läs sparat jobb och poll igen vid nästa tillåtna trigger. |
| Resultat inkommet före lokal commit | Resultat och outbox rullas tillbaka tillsammans; hämta resultat igen. |
| Resultat/outbox committat före processdöd | Resultat ligger kvar för replay; gör ingen ny AI-körning. |
| Watch tar emot, ACK försvinner | Skicka samma resultat-ID/payload igen; mottagaren deduplicerar beständigt. |
| Cancel eller ny generation under pågående request | Lokalt fencing/state avvisar det sena resultatet. |
| Credentials löper ut | Blockera; explicit refresh återupptar samma jobb, ingen dold fallback. |

En verklig leverantör måste visa att idempotency stöds för hela nödvändiga
retry-fönstret och att terminala resultat kan hämtas igen. Fixture-serverns
idempotency finns kvar i dess SQLite-fil tills labbdata raderas. Om leverantören
saknar funktionen får adaptern inte påstå samma garanti; eventuell dubbel
bearbetning/kostnad och förlorat svar behöver eget beslut. Detta kontrakt kräver
inte att vi bygger en egen produktionsserver.

Cancel är lokal och omedelbar för kö/callbacks; servercancel är separat och best
effort. Ett redan skickat meddelande kan hinna visas trots cancel. Mottagaren
avvisar äldre generationer först när den känner till en nyare. Retention,
servercleanup och dataradering behöver leverantörsspecifika regler.

## Resultat, ACK och actions

Resultat v1 innehåller transcript, summary, category och action-förslag.
Resultat-ID är SHA-256 av UTF-8-strängen `result-v1:` + jobbnyckeln. Resultat
och leveransenvelope registreras atomärt i samma SQLite-transaktion.
Outbox levereras bara till dess watch-ID. Samma resultat-ID får inte återanvändas
med en annan payload. ACK matchar watch-ID och resultat-ID och måste ha status
`accepted`; dubblett-ACK är ofarligt. `accepted` betyder beständig mottagning,
inte att användaren godkänt ett action-förslag.

Fake-watch har en separat SQLite receipt-tabell och högsta generation per
recording. Den gör inga kalender-, alarm- eller reminder-anrop. Därför bevisar
testen en mottagning per resultat, inte exakt-en-gång-effekter i externa appar.
Sådana effekter kräver ett eget sparat action-ID, användarens auto-create-policy,
platform-target-ID och recovery vid avbrott mellan extern effekt och lokal commit.

Den befintliga `sendResultToWatch()` skickar `voice_memo/result` utan resultat-ID
och använder en 20 s undo-timer för `onConfirmed`; frånkopplad watch kan direkt
utlösa auto-create. **Den timern är ingen mottagningskvittens.** Det befintliga
firmwareflödet publicerar resultatet lokalt men skickar inte detta kontrakts ACK.
Delivery-ACK och auto-create/undo-policy måste hållas isär vid migreringen.
Detta arbete ändrar inte dagens användarbeteende eller watch-protokoll. Första
native-prototypen kan visa resultat utan actions; kvitterad replay kräver senare
versionsförhandlat firmwarestöd och verifierad beständig deduplicering.

## Körning och verifierade gränser

Från repo-roten, Python 3.12 eller senare, endast standardbibliotek:

```bash
python3 -m unittest discover -s scripts/companion_hil/tests -p test_remote_jobs.py -v
PYTHONPATH=scripts/companion_hil python3 -m remote_jobs.run_fixture \
  --output /tmp/zswatch-remote-recovery-001
PYTHONPATH=scripts/companion_hil python3 -m remote_jobs.server \
  --state-dir /tmp/zswatch-remote-server-001 --port 8765
```

Replay-output måste vara ny. `result.json`, `timeline.jsonl` och separata
phone/server/watch-databaser bevaras där. Återstarta en fristående server med
samma state-dir och `--resume-existing`; flaggan kräver fixture-markören.
Servern binds till `127.0.0.1`, startar inga riktiga uploads och använder ett
explicit kontrollkommando för att bli klar. Testkontrollerna är inte ett
produktions-API. Med en ansluten Android-telefon kan `adb -s SERIAL reverse
tcp:8765 tcp:8765` senare exponera samma fixture för prototypen; cleartext-policy
ska då begränsas till debug-konfigurationen. Ingen sådan tunnel har satts upp nu.

Fixture-API:

| Request | Effekt |
|---|---|
| `POST /v1/jobs` med `spec` och `idempotency_key` | Acceptera/återförenas; svar 202 med remote-ID/state. |
| `GET /v1/jobs/<remote-ID>` | `running`, `succeeded`, `failed` eller `cancelled`; färdigt resultat kan hämtas igen. |
| `POST /__fixture__/complete/<remote-ID>` med `{}` | Spara det syntetiska resultatet. |
| `POST /__fixture__/fail/<remote-ID>` eller `cancel/...` med `{}` | Spara ett terminalt fel/avbrott. |
| `POST /__fixture__/fault` med `{"fault":"drop_after_accept"}` | För nästa submit: commit serverjobbet och stäng anslutningen före svar. |
| Samma fault-endpoint med `rate_limit` eller `auth_expired` | Nästa submit ger 429/Retry-After eller 401 utan serveraccept. |

24 tester passerar på värddatorn. De använder riktig loopback-HTTP och SQLite;
två tester dödar en separat process med SIGKILL precis före respektive efter
resultat/outbox-commit. Den delade 13-stegs JSON-tracen ger ett serverjobb och
en fake-watch-receipt trots tappat submit-svar, återöppnade stores och tappat ACK.
Slutstatus är `CONTRACT_VERIFIED`; companion-acceptans är alltid `NOT_RUN`.

Detta verifierar inte Android/iOS-processägarskap, BLE, suspension/wakeups,
ljudupload, riktiga modeller, firmwarekvittens, verklig action-idempotens eller
mobil SQLite-implementation. Nästa adapter ska köra samma golden trace och
processavbrottsgränser i vald runtime; normal bakgrundsleverans kräver fysisk
telefon enligt den större planen.

## Android follow-up, 2026-10-03

A native serialized-owner adapter now reuses these JSON fixtures and canonical
identities. It uses a separate atomic-file job journal and service-owned loopback
network executor. Real Nokia tests reunited a lost submit response with one
server job, recovered a pending result after a crash, and retained result/outbox
after another crash without Flutter. The temporary ADB tunnel was removed after
testing. See [native Android adapter and limits](REMOTE_JOB_ANDROID_PROTOTYPE.md).
Current firmware does not implement the result ACK; the physical outbox remains
pending. No audio upload, model execution, actions or iOS acceptance are claimed.
