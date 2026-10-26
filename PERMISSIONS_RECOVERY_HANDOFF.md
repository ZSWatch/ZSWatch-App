# Recover permissions and release fixes

This branch preserves the committed work from `jakkra_permissions_setup` so
another agent can recover changes missing from `feature/dictated-replies`.
It is a recovery source, not an integrated replacement for the reply branch.

## Compared snapshots

- Recovery source: `0dcefb1e8424b7ede451255563cf84296ca10251`
  (`jakkra_permissions_setup`).
- Integration target inspected on 2026-10-26:
  `f44844c1d63610a3c5c47f6752b1bc0d446285c7`
  (`origin/feature/dictated-replies`). Fetch it again before starting.
- The 33 source commits below have no identical patch on the inspected target.
  This does **not** mean 33 features are absent: several were independently
  implemented or replaced there.
- Existing uncommitted changes and untracked files in the original checkout
  were excluded. This branch contains the committed source plus this handoff.

## What prompted the investigation

On the connected dashboard, Restart Watch and Find watch are stacked and take
too much vertical space. Commit `6dadcd3` already fixed this: a compact shared
row, 36-pixel minimum button height, and matching Find watch styling in Developer
tools. Its only changes are in:

- `zswatch_app/lib/ui/screens/dashboard/dashboard_screen.dart`
- `zswatch_app/lib/ui/screens/dashboard/companion_find_watch_button.dart`
- `zswatch_app/lib/ui/screens/developer/developer_screen.dart`

Those changes are absent from the inspected reply branch. The user also wants
the other missing work recovered, rather than only recreating this layout.

## Preserve the newer reply-branch behavior

The reply branch has newer first-run onboarding before pairing, notification
reply processing, cloud-key setup before selecting a watch, shared voice
preferences, and location permission/default migration logic. Do not overwrite
these with the older source files.

Permission consent already enables location sharing there, with additional
protection for existing user choices. Approximate and cached location handling
also has newer changes. However, the source's Android `getCurrentLocation`
request and fused-provider support are still absent; its cached-fix changes
do not replace that fresh-location behavior.

The old post-connection setup flow, shared Allow-button rows, and card spacing
should be reconciled with the newer onboarding rather than restoring a second
competing flow. The earlier background-location disclosure text differs from
the newer permission guidance; review the intended wording without discarding
the guidance.

## Missing work and source commits

| Source commit | Change | Target status / integration note |
| --- | --- | --- |
| `50da4f1` | Offer missing permissions after first connection | Replaced in purpose by newer first-run onboarding; reconcile, do not duplicate. |
| `a5b78d3` | iPhone permission-setup UI test flow | Original flow absent; adapt coverage to current onboarding. |
| `94da6c9` | Permission setup card spacing | Original cards absent; assess against current onboarding. |
| `12964d4` | Shared permission row with explicit Allow button | Original component absent; preserve newer location guidance and defaults. |
| `6dadcd3` | Compact Restart/Find watch row and Developer styling | Missing. |
| `e0abe66` | Put speech tests in a Test tab in Shell | Missing; tests remain under Quick Actions. |
| `db39e59` | Read coredump from `/lvgl_lfs` | Missing; Android/iOS still use `/user/coredump.txt`. |
| `1248191` | OpenRouter Allow/Cancel voice-data consent before saving key | Missing; keep newer key-save and auto-processing behavior. |
| `ccd193e` | iOS privacy manifest and microphone text | Missing. |
| `9b2ef8c` | Version update and Android target SDK 36 | Target still has SDK 35 and app version `1.1.0+1`; choose the final version deliberately. |
| `092f2ad` | Hide Demo Mode key and history errors | Missing. |
| `caec337` | Reload OpenRouter key when leaving Demo Mode | Missing; preserve newer key-save behavior and tests. |
| `5cf5692` | Store screenshot capture flow and framing script | Missing. |
| `ad10230` | Display actual app version in Settings | Missing; Settings still hardcodes `1.0.0 (1)`. |
| `642c0c2` | Background-location disclosure wording | Exact text absent; newer location explanation exists. Reconcile wording. |
| `a4439eb` | Open battery settings instead of direct exemption request | Missing; also includes the store feature-graphic script. |
| `1a3463b` | Release checklist | Missing. |
| `0055c73` | Remove phone benchmark microphone recording; update photo text | Missing; target retains AudioRecorder and record dependency. |
| `6493319` | Remove coredump analysis server; retain download/export | Missing; target retains server UI and analysis service. |
| `f79befe` | Regenerate plugin registrants after removing record | Missing; apply with dependency cleanup. |
| `1702fcb` | Limit HTTP to local hosts and remove TLS verification bypass | Missing on Android/iOS. |
| `0abd2e5` | Version `1.2.0+10` | Historical version step; do not apply every intermediate version. |
| `fd08471` | Native library licenses and unused-package cleanup | Missing. |
| `2f24642` | Frame screenshots in all App Store iPhone sizes | Missing. |
| `6fefc4e` | Release checklist and privacy-policy draft | Review final state with subsequent docs commits. |
| `aaed911` | Capture Settings/Shell in store screenshot tests | Missing. |
| `ae42c15` | Screenshot notes | Missing with screenshot tooling. |
| `620928f` | Move privacy-policy update to website | Review final docs state; do not restore the superseded draft. |
| `23d6647` | Record Android signing setup on Mac | Missing documentation. |
| `8fe5c8f` | Retry rejected Android GATT rediscovery within deadline | Missing; target still immediately fails rejected discoverServices. |
| `80c75f2` | Android status-bar screenshot fit and OnePlus results | Missing screenshot/docs changes; this is not an app status-bar layout fix. |
| `4799013` | Fresh coarse-location request; enable sharing on permission grant | Partial overlap: sharing defaults exist in newer form; getCurrentLocation/fused provider is missing. |
| `0dcefb1` | Version `1.2.0+11` | Source's final version; reconcile with intended release version. |

## Suggested integration and validation

Start an implementation branch from the latest `origin/feature/dictated-replies`
and selectively recover the missing work from this branch. Do not replace the
reply branch with this older snapshot or merge by choosing all source versions.
Keep newer notification/recording fixes from main and the reply feature.

Read `AGENTS.md` first. Run the relevant Flutter/native checks after integrating;
this handoff was produced by Git/source inspection, not a runtime test. Keep
hardware tests separate and ask before touching phone pairing or watch data.

Useful comparison commands:

```sh
git fetch origin
git cherry -v origin/feature/dictated-replies origin/codex/recover-permissions-fixes
git show 6dadcd3
git log --reverse --oneline 8d2b955..0dcefb1
git diff origin/feature/dictated-replies origin/codex/recover-permissions-fixes -- zswatch_app/lib/ui/screens/dashboard
```
