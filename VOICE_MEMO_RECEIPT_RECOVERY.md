# Voice receipt recovery in the Flutter app

Implemented on 2026-10-02 as a phone-free prerequisite to the companion runtime
prototype. This is production app code, separate from the Python remote-job
reference model. It uses the existing Drift schema (version 6); no migration or
native/Dart ownership decision is introduced.

## Behavior

`VoiceMemoRecoveryService` runs once at app startup, alongside BLE initialization.
Voice memo list/detail streams and sync await the same provider Future. Recovery
does not start inference, use the radio, send results or delete watch recordings.

For existing DB records it can:

- Adopt a complete published `.zsw_opus` file when the process died before its
  downloaded flag/path was committed.
- Publish a complete, manifested stage when the final destination is absent.
  New stages have a flushed `receipt.json` written after the flushed payload.
  The envelope names the destination and byte count. Adoption additionally
  checks container v1, size, timestamp, duration, frame count and full frame
  coverage against the known watch metadata. Dirty/partial stages are retained.
- Rebuild a missing Ogg conversion from the verified raw recording. Conversion
  failure preserves the raw receipt and is logged separately.
- Clear unavailable raw/conversion paths. Missing raw clears the downloaded flag
  and time, while preserving transcription, AI results, any remaining conversion,
  and the recorded watch-deletion state.

Updates run in a Drift transaction and compare DB ID, filename, watch metadata
and receipt fields against the snapshot. A concurrent delete or metadata/receipt
change prevents that update; recovery never inserts a deleted DB record.
Repeated recovery keeps the original downloaded timestamp and does not rewrite
already available conversions. Sync now attempts only recordings present in the
current watch list, rather than blindly retrying every unsynced DB record.

The store serializes recovery and publication within one Dart runtime. Live
prepared stages are excluded. Stages without manifests, ambiguous candidates,
unknown files and existing destinations are retained without overwrite or
automatic import. A newly published stage's empty manifest directory is removed
after DB recovery succeeds, only when it contains that manifest alone. A crash
between these steps can still leave an empty stage for inspection.

Existing downloaded receipts retain the prior parser/size validation behavior,
including previously accepted dirty-stop recordings. The stronger closed-container
checks apply to *new recovery adoption*; this change does not rewrite the shared
parser's existing compatibility rules. Existing converted files are checked for
availability, not decoded to prove their audio integrity.

The sync service cancels its connect-delay timer on disconnect/dispose and stops
a pending startup recovery from reviving a disposed instance. Delivery ACK,
recording delete ACK, durable AI/outbox state and action execution are separate
work; this recovery pass does not substitute for any of them.

## Host verification

From `zswatch_app`:

```bash
flutter pub get
flutter test --no-pub test/voice_memo_recovery_service_test.dart \
  test/voice_memo_sync_service_test.dart test/voice_memo_file_store_test.dart \
  test/zsw_opus_parser_test.dart --reporter expanded
dart analyze lib/app.dart lib/data/database/app_database.dart \
  lib/data/repositories/voice_memo_repository.dart lib/providers/voice_memo_providers.dart \
  lib/services/voice_memo/voice_memo_file_store.dart \
  lib/services/voice_memo/voice_memo_recovery_service.dart \
  lib/services/voice_memo/voice_memo_sync_service.dart \
  test/voice_memo_recovery_service_test.dart test/voice_memo_sync_service_test.dart \
  test/support/host_sqlite.dart test/support/voice_recovery_crash_worker.dart
flutter build apk --debug --no-pub
```

The selected suites cover 63 tests: 17 new recovery tests, 11 sync tests,
4 atomic-file tests and 31 existing parser/container tests. The recovery tests
use on-disk SQLite with the app's real Drift schema/repository and real file I/O.
Three tests start separate Flutter test processes and SIGKILL the actual worker
after staging, after rename, and after the downloaded DB commit. Recovery then
reopens the DB, adopts/preserves audio, builds Ogg and checks repeatability.
The child keeps its connection open and uses WAL; host tests load the installed
SQLite runtime SONAME on Linux. `sqlite3` is now an explicit test dependency at
the same resolved 2.9.4 version, with no dependency upgrades.

The crash worker is outside default `*_test.dart` discovery and requires explicit
test defines. Do not invoke it against a real app database. Each parent test uses
a new temporary directory, bounded waits and cleanup of its own worker.

Analyzer is clean and Android debug APK compilation passed. The APK has not been
installed or run on a physical phone. Existing locally modified submodules were
used by the build and remain uncommitted. Host process death does not establish
mobile lifecycle/wakeup behavior, storage availability before first unlock,
native MCUmgr behavior or background BLE reliability.

## Remaining integration work

The current filename-based DB is not a durable multi-watch/generation identity.
Unknown recordings cannot be safely imported automatically without deletion
tombstones/receipt identity. Staging cleanup remains conservative and may retain
old incomplete/ambiguous data. A future native runtime must share the storage
owner/locking and schema authority rather than run independently beside this
Dart implementation. OS-level power-loss guarantees and directory fsync are not
claimed by the rename/SQLite crash tests.

Phone testing should first confirm ordinary recording/sync/playback, startup
recovery and storage errors, then locked-screen/background and process-death
scenarios in the [implementation plan](COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md).
