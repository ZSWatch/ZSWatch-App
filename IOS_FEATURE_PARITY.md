# iOS feature parity

Initial inventory, 2026-10-12. Implementation baseline: app `d7a51f1`, Nordic
`f67c186`, fllama `115e799`, firmware source `0f56aec7`. Firmware source is not
proof of the installed image. See `IOS_MAC_BASELINE.md` for build and rig evidence.

Implementation checkpoint: see `IOS_NATIVE_COMPANION_PROGRESS.md`. Native BLE,
UUID selection and durable telemetry projection are implemented and host-tested;
physical Bluetooth consent and the remaining product integration are pending.

The inventory combines the current UI with the dashboard/start/settings and
service flows before Android's native shell (`0a8f430^`). Android's unfinished
features do not define iOS scope. All six existing home entrances are retained.
“Pending” means implementation or physical acceptance is outstanding; none of
the rows below is closed by an unsigned build or a USB probe.

| Feature | Previous behavior / source | New implementation | iOS difference | Verification |
| --- | --- | --- | --- | --- |
| Onboarding and permissions | Permission onboarding; Bluetooth/location explanations | Native Bluetooth request/status contract and existing permission UI | CoreBluetooth authorization; no Android battery exemption | Pending first-install phone flow |
| Nearby scan and selection | ScanScreen / BleScanner, signal strength and selection | Native foreground discovery in existing Add Watch route | Peripheral UUID, not MAC | Pending phone scan |
| Pairing | Encrypted GATT operation triggers OS pairing | Pending native discovery/subscriptions | Pairing and Share System Notifications are system decisions | Pending ordinary pairing |
| Saved watch and reconnect | Start page and watch repository | Native persisted intent; Dart Ready catalogue projection | Stable CoreBluetooth identifier | Pending cold launch and out-of-range reconnect |
| Rename / primary watch / selection | Saved-watch menu and database | Existing catalogue projection accepts iOS UUIDs | UUIDs and MACs validated against native owner | Pending phone flows |
| Forget watch | Delete app metadata and Android unbond where supported | Durable native Stop/Forget fence and Settings explanation | App cannot delete an iOS system bond; explain Settings step | Pending stale-callback and phone checks |
| Start / Stop | Connect / disconnect and persistent-connection setting | Native session controller with restoration identifier and fenced delegates | Force-quit requires reopening; Stop must suppress restoration | Pending persistence and physical lifecycle |
| Restart Watch | Dashboard restart via SMP | Pending coordinator-owned Nordic reset | Do not automatically replay reset | Pending confirmed restart/reconnect |
| Home summary and six entrances | Battery, version, steps, pulse; Health, Notifications, Analytics, Watchface, Developer, Voice | Existing UI retained; native snapshots pending | Live versus cached data must be explicit | Pending all six routes |
| ANCS notifications | iOS notification screen explains firmware ANCS | Retain firmware ANCS; native link/pairing integration pending | No third-party app notification listener or Android package filters | Pending system notification and reconnect |
| Notification actions | Firmware ANCS action support | Retain firmware path | Only actions exposed by ANCS | Pending actual actionable notification |
| Time and timezone | WatchService time sync; firmware CTS | CTS retained; explicit/watch-requested app sync uses whole clock packets | Prevent conflicting time sources | Pending time and timezone change |
| Media metadata | Firmware AMS on iOS | Retain firmware AMS | No Android media-session bridge | Pending actual player metadata |
| Media play/pause/next | Firmware AMS commands | Retain firmware path | Depends on active player/AMS support | Pending physical controls |
| Find watch | Developer Find toggle and Gadgetbridge find command | Native generation-checked queued Find commands | Respect Stop/session fencing | Pending watch vibration/stop |
| Find phone | Existing iOS support must be checked against firmware find event | Pending inventory closure in implementation | Audio/notification execution policy differs from Android | Pending source contract and phone test |
| GPS request | GpsService handles watch gps_power request | Pending native CoreLocation relay | Foreground/always permission and background policy required | Pending watch Weather request and denied permission |
| Weather | Watch triggers GPS and HTTP from Weather app | Pending native GPS/HTTP | Stale locations must carry age/precision policy | Pending actual weather display |
| HTTP relay | HttpService handles request id, URL and response | Pending bounded URLSession relay | Short background opportunity; no permanent HTTP service | Pending request/error/session-fence tests |
| Activity/steps collection | HealthSyncService stores act messages in Drift | Native receipt journal with transactional Dart projection and watermark | Establish one SQLite writer before collection | Pending no-UI collection and deduplication |
| Heart rate | Current pulse, history and HeartRateScreen | Native act receipt/transactional history projection | Existing data model retained | Pending actual pulse and history |
| Health Today/Week/Month | StepsHistory/activity breakdown/heart-rate views | Existing UI retained; collection pending | Historical placeholders are not new requirements | Pending three ranges and refresh |
| History/retention | Existing database cleanup policy | Pending projection/cleanup integration | Native and Dart ownership must be explicit | Pending retained-data check |
| Battery history | Analytics and battery samples | Native durable battery receipts and Dart projection | Show new samples when UI reattaches | Pending background receipt and UI refresh |
| Connection analytics | Connect/disconnect/reconnect events | Native connection receipts and transactional Dart projection | Process loss differs from force-quit and explicit Stop | Pending history/deduplication |
| Voice list and automatic discovery | VoiceMemoSyncService list plus firmware voice_memo protocol | Pending native list and durable inbox | BLE event secures a job; does not guarantee immediate AI | Pending actual list/background event |
| Recording download/resume | Nordic filesystem plus verified file publication | Pending coordinator-owned SDK transfer | Preserve partial staging and watch originals | Pending acknowledged bytes/integrity and retry |
| Playback | Raw/Ogg conversion and player | Existing shared Dart retained; native receipts pending | Verify actual iOS decoder/plugin path | Pending real speech playback |
| Search/filter/archive | Existing voice list and detail controls | Existing UI retained; native receipt model integration pending | No silent removal of controls | Pending all controls |
| Local delete and batch actions | Existing list multi-select/delete/process controls | Pending shared receipt/job integration | Watch deletion only after verified protocol acknowledgment | Pending selected-only deletion and batch |
| Copy/edit transcript | Voice detail edit/copy | Existing Dart flow retained | Persist edits and fence older attempts | Pending edit/relaunch |
| Transcribe separately / transcribe again | Shared companion processor and voice controls | Pending native job scheduling using existing Dart processor | CPU/GPU execution policy; offline files usable without BLE | Pending actual transcript and retry |
| Analyze again | Existing transcript reused by shared processor | Pending same durable job owner | No new classification scope | Pending preserved transcript/result |
| Automatic transcription / optional analysis | AI settings and processing policy | Pending native queue plus shared processor | Show waiting status when iOS declines execution | Pending policy, expiration and recovery |
| Model select/import/download/delete | AI model settings and existing model repositories | Existing Dart retained | Verify paths and memory on iPhone 11 | Pending all model controls |
| Calendar/reminders | AppDelegate EventKit productivity bridge | Retain logic; register per execution engine | iOS 17 full-access APIs are availability-guarded | Pending actual event/reminder and denial |
| Timer/alarm actions | AppDelegate schedules local notifications | Retain and correct misleading Clock naming/UI claims | Local notification, not system Clock timer/alarm | Pending scheduled alert; label check |
| Firmware file selection and slots | FirmwareManager and modified Nordic fork | Pending coordinator-owned update adapter | Only SDK-supported image variants may be labeled supported | Pending selected image/slot and real update |
| Firmware progress/error/retry/reconnect | Existing update UI, SDK callbacks | Pending exclusive operation owner | Use negotiated write length; safe pause/expiration | Pending installed version, throughput and retry |
| Filesystem resources | FileSystemService and filesystem image UI | Pending coordinated Nordic upload | Measure ordinary firmware before large images | Pending representative verified upload |
| Watchface select/crop/upload/apply/reset | Existing watchface UI and protocol | Pending native transfer/status integration | Preserve existing image format and firmware checks | Pending actual applied image/reset |
| Shell | Developer shell using Nordic ShellManager | Pending same native SDK owner | No custom SMP | Pending actual response and timeout |
| Filesystem browser/download/upload | Developer File System | Pending coordinated SDK access | No competing per-UI transports | Pending file listing and verified transfer |
| Sensors | Sensor GATT service and debug UI | Pending native sensor subscriptions | Use actual CoreBluetooth characteristic lengths | Pending sample and unsubscribe |
| Firmware logs | Log Viewer and firmware BLE log framing | Bounded native NUS log framing and observation channel | Logs should avoid routine private payload dumps | Pending fragmented frames and unsubscribe |
| Communication log | Developer BLE traffic screen | Native completed-write/reassembled-message observation channel | Diagnostic subscribers cannot own link lifetime | Pending attach/detach |
| Crash summaries/history/download | Existing crash UI, protocol and coredump filesystem | Pending native protocol/SDK operations | Keep server URL setting and existing decode flow | Pending actual available summary/file |
| Settings/about/licenses | Persistent connection, AI, permissions, version, sources, licenses, coredump URL | Existing UI retained; platform capabilities pending | Android-only settings cannot be presented as working iOS controls | Pending complete settings walk-through |
| Demo mode | Existing fake data and settings switch | Pending native branch isolation | Demo must send no real watch command | Pending offline demo and exit |

Excluded by the implementation plan: experimental voice chat, remote/hybrid AI,
changes to existing classification quality, App Store publication and long
endurance tests. Existing recordings remain in scope.
