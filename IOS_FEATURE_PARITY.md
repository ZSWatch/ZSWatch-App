# iOS feature parity

Initial inventory, 2026-10-12. Implementation baseline: app `d7a51f1`, Nordic
`f67c186`, fllama `115e799`, firmware source `0f56aec7`. Firmware source is not
proof of the installed image. See `IOS_MAC_BASELINE.md` for build and rig evidence.

Implementation checkpoint: see `IOS_NATIVE_COMPANION_PROGRESS.md`. Native BLE,
UUID selection and durable telemetry projection are implemented and host-tested;
The signed normal app reached encrypted Ready on the iPhone, downloaded all 26
recordings and passed all six route checks. Remaining acceptance is listed below
and in `IOS_NATIVE_COMPANION_PROGRESS.md`.

The inventory combines the current UI with the dashboard/start/settings and
service flows before Android's native shell (`0a8f430^`). Android's unfinished
features do not define iOS scope. All six existing home entrances are retained.
“Pending” means implementation or physical acceptance is outstanding; none of
the rows below is closed by an unsigned build or a USB probe.

| Feature | Previous behavior / source | New implementation | iOS difference | Verification |
| --- | --- | --- | --- | --- |
| Onboarding and permissions | Permission onboarding; Bluetooth/location explanations | Native Bluetooth request/status contract and existing permission UI | CoreBluetooth authorization; no Android battery exemption | Pending first-install phone flow |
| Nearby scan and selection | ScanScreen / BleScanner, signal strength and selection | Native foreground discovery in existing Add Watch route | Peripheral UUID, not MAC | Phone found one ZSWatch UUID/RSSI; encrypted Ready with matching live status/version generations and UUID verified |
| Pairing | Encrypted GATT operation triggers OS pairing | Encrypted subscription with pairing grace deadline | Pairing and Share System Notifications are system decisions | Normal app reached encrypted Ready before the successful UI-automation run; pairing attribution is not assigned to XCTest. Earlier pairing timeout evidence retained |
| Saved watch and reconnect | Start page and watch repository | Native persisted intent; Dart Ready catalogue projection | Stable CoreBluetooth identifier | Pending cold launch and out-of-range reconnect |
| Rename / primary watch / selection | Saved-watch menu and database | Existing catalogue projection accepts iOS UUIDs | UUIDs and MACs validated against native owner | Pending phone flows |
| Forget watch | Delete app metadata and Android unbond where supported | Durable native Stop/Forget fence and Settings explanation | App cannot delete an iOS system bond; explain Settings step | Pending stale-callback and phone checks |
| Start / Stop | Connect / disconnect and persistent-connection setting | Native session controller with restoration identifier and fenced delegates | Force-quit requires reopening; Stop must suppress restoration | Pending persistence and physical lifecycle |
| Restart Watch | Dashboard restart via SMP | Exclusive Nordic reset with acknowledged result and no replay | Do not automatically replay reset | Pending confirmed restart/reconnect |
| Home summary and six entrances | Battery, version, steps, pulse; Health, Notifications, Analytics, Watchface, Developer, Voice | Existing UI retained; native live battery/version/pulse snapshots | Live versus cached data must be explicit | Six physical routes passed; Health Today/Week/Month navigation passed; live battery/version/pulse shown |
| ANCS notifications | iOS notification screen explains firmware ANCS | Retain firmware ANCS; native link/pairing integration pending | No third-party app notification listener or Android package filters | Pending system notification and reconnect |
| Notification actions | Firmware ANCS action support | Retain firmware path | Only actions exposed by ANCS | Pending actual actionable notification |
| Time and timezone | WatchService time sync; firmware CTS | CTS retained; explicit/watch-requested app sync uses whole clock packets | Prevent conflicting time sources | Pending time and timezone change |
| Media metadata | Firmware AMS on iOS | Retain firmware AMS | No Android media-session bridge | Pending actual player metadata |
| Media play/pause/next | Firmware AMS commands | Retain firmware path | Depends on active player/AMS support | Pending physical controls |
| Find watch | Developer Find toggle and Gadgetbridge find command | Native generation-checked queued Find commands | Respect Stop/session fencing | Pending watch vibration/stop |
| Find phone | Source inspection finds this only in the separate Chronos watch application/protocol | No Gadgetbridge/app handler to retain | Adding a new protocol/phone finder is outside existing product parity | Inventory closed; no new support claimed |
| GPS request | GpsService handles watch gps_power request | Native request-scoped CoreLocation relay and sharing policy | Foreground/always permission and background policy required | Pending watch Weather request and denied permission |
| Weather | Watch triggers GPS and HTTP from Weather app | Native GPS and bounded HTTP; physical display pending | Stale locations must carry age/precision policy | Pending actual weather display |
| HTTP relay | HttpService handles request id, URL and response | Bounded native URLSession/XPath relay with deadline and session fences | Short background opportunity; no permanent HTTP service | Pending request/error/session-fence tests |
| Activity/steps collection | HealthSyncService stores act messages in Drift | Native receipt journal with transactional Dart projection and watermark | Establish one SQLite writer before collection | Pending no-UI collection and deduplication |
| Heart rate | Current pulse, history and HeartRateScreen | Native act receipt/transactional history projection | Existing data model retained | Pending actual pulse and history |
| Health Today/Week/Month | StepsHistory/activity breakdown/heart-rate views | Existing UI retained; collection pending | Historical placeholders are not new requirements | Today/Week/Month navigation passed on phone; background refresh/data semantics still pending |
| History/retention | Existing database cleanup policy | Pending projection/cleanup integration | Native and Dart ownership must be explicit | Pending retained-data check |
| Battery history | Analytics and battery samples | Native durable battery receipts and Dart projection | Show new samples when UI reattaches | Pending background receipt and UI refresh |
| Connection analytics | Connect/disconnect/reconnect events | Native connection receipts and transactional Dart projection | Process loss differs from force-quit and explicit Stop | Pending history/deduplication |
| Voice list and automatic discovery | VoiceMemoSyncService list plus firmware voice_memo protocol | Native list and durable inbox with captured processing policy | BLE event secures a job; does not guarantee immediate AI | Actual 26-item list and verified cached receipts on normal app; new-event/background acceptance pending |
| Recording download/resume | Nordic filesystem plus verified file publication | Coordinator-owned Nordic transfer with verified publication/prefix recovery | Preserve partial staging and watch originals | 26 BLE receipts downloaded (578145 source bytes); owned 155127-byte speech file copied back and SHA256 matched. Interrupted-download acceptance pending |
| Playback | Raw/Ogg conversion and player | Verified native receipt import and retained legacy playback | Verify actual iOS decoder/plugin path | Actual phone decoder loaded 0:07; playback advanced to 0:02 and pause worked. Combined shell test failed separately; seek/share pending |
| Search/filter/archive | Existing voice list and detail controls | Native identity search, categories, journal archive/title annotations; separate earlier-recordings view | Private search returns identities; earlier rows are not adopted by filename | Widget checks pass; phone controls pending |
| Local delete and batch actions | Existing list multi-select/delete/process controls | Selected-only jobs, recoverable Recently deleted, explicit permanent phone purge with retryable cleanup | Watch originals and already-created calendar/alerts retained; only generated local copies removed | Host/widget removal, restore, purge interruption and selected-only cleanup pass; phone acceptance pending |
| Copy/edit/export transcript | Voice detail edit/copy and sharing | Native saved edit revisions, copy, verified Ogg/text share copies, saved revision access | Older attempts cannot overwrite edits; earlier-row editing/processing migration pending | Host/widget edit/export checks pass; actual sharing/relaunch pending |
| Transcribe separately / transcribe again | Shared companion processor and voice controls | Native fenced jobs and one shared Dart worker; checkpoints and foreground/scheduled CPU policy | CPU/GPU execution policy; offline files usable without BLE | Pending actual transcript and retry |
| Analyze again | Existing transcript reused by shared processor | Native job generations reuse a saved transcript for reanalysis | No new classification scope | Pending preserved transcript/result |
| Automatic transcription / optional analysis | AI settings and processing policy | Native inbox-captured opt-in policy and shared worker under iOS execution grants | Show waiting status when iOS declines execution | Pending policy, expiration and recovery |
| Model select/import/download/delete | AI model settings and existing model repositories | Existing Dart retained | Verify paths and memory on iPhone 11 | Whisper Tiny English selection/download passed offline on phone; import/delete, original-selection restore and inference acceptance remain pending |
| Calendar/reminders | AppDelegate EventKit productivity bridge | Retain logic; register per execution engine | iOS 17 full-access APIs are availability-guarded | Pending actual event/reminder and denial |
| Timer/alarm actions | AppDelegate schedules local notifications | Retain and correct misleading Clock naming/UI claims | Local notification, not system Clock timer/alarm | Pending scheduled alert; label check |
| Firmware file selection and slots | FirmwareManager and modified Nordic fork | Native Nordic MCUboot parsing and slot-one SDK upgrade; reported-index preflight | Untested variants remain unverified; no custom SMP | Parser/state/widget checks pass; real image/slot acceptance pending |
| Firmware progress/error/retry/reconnect | Existing update UI, SDK callbacks | Exclusive native update owner, fresh boot/hash check, bounded background grant and terminal teardown | Negotiated buffers/writes; admitted unknown outcomes never reset-replayed | Host/full-SDK/widget checks pass; installed version/throughput/retry pending |
| Filesystem resources | FileSystemService and filesystem image UI | Native validated /S/full_fs upload, full pre/post-boot readback and acknowledged reset | Large images gated on measured ordinary firmware first | Host resource checks pass; representative physical upload pending |
| Watchface select/crop/upload/apply/reset | Existing watchface UI and protocol | Exclusive native Nordic upload, full readback, NUS apply/reset and durable status | Preserve existing image format and firmware checks | Pending actual applied image/reset |
| Shell | Developer shell using Nordic ShellManager | Exclusive native Nordic preparation/shell with signed Zephyr return code | No custom SMP | Pending actual response and timeout |
| Filesystem tools | Developer File System log probes/downloads; Files tab directed recordings to Voice Memos | Native coordinated log probing/downloads; recording/resources/watchface owners supply their file paths | No competing per-UI transports; a general browser was not an existing feature | Physical probes/transfers pending |
| Sensors | Sensor GATT service and debug UI | Native discovered sensor CCCDs; view-close unsubscribe and session fences | Use actual CoreBluetooth characteristic lengths | Pending sample and unsubscribe |
| Firmware logs | Log Viewer and firmware BLE log framing | Bounded native NUS log framing and observation channel | Logs should avoid routine private payload dumps | Pending fragmented frames and unsubscribe |
| Communication log | Developer BLE traffic screen | Native completed-write/reassembled-message observation channel | Diagnostic subscribers cannot own link lifetime | Pending attach/detach |
| Crash summaries/history/download | Existing crash UI, protocol and coredump filesystem | Native summary parser, bounded known file download and explicit erase | Keep server URL setting and existing decode flow | Pending actual available summary/file |
| Settings/about/licenses | Persistent connection, AI, permissions, version, sources, licenses, coredump URL | Existing UI retained; platform capabilities pending | Android-only settings cannot be presented as working iOS controls | Pending complete settings walk-through |
| Demo mode | Existing fake data and settings switch | Native Stop-before-preview, synthetic read-only client and prior-intent exit | No real hardware commands or private recording import; interrupted process remains stopped | Provider/widget isolation and all six routes pass; physical preview pending |

Excluded by the implementation plan: experimental voice chat, remote/hybrid AI,
changes to existing classification quality, App Store publication and long
endurance tests. Existing recordings remain in scope.
