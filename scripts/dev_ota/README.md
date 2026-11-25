# Dev OTA: firmware from the dev machine to the phone

Install watch firmware built on the dev machine (the Mac Mini) from the phone,
wherever the phone is. Android only for now (iOS: see
`IOS_COMPANION_DELIVERY.md`).

```
build firmware ─▶ dev_ota.py publish ─▶ server ◀── app long-polls (foreground)
                                          ▲          │ dialog: Install?
                    dev_ota.py status ◀── │ status ◀─┘ native DFU, reports back
```

## Setup (once)

```sh
scripts/dev_ota/setup_mac.sh
```

It installs a copy of `dev_ota.py` in `~/.zswatch_dev_ota/` (launchd may not
read `~/Documents`), runs it at login on `127.0.0.1:8787`, mounts it with
`tailscale serve` at `https://<mac>.<tailnet>.ts.net/zswatch-ota`, and prints
the URL and token. Rerun it after changing `dev_ota.py`.

In the app: Settings → Firmware Update → **Dev Firmware Server**, paste URL and token, Save.

HTTPS through Tailscale works at home and away, so one URL is enough. The app
only allows HTTPS (plus localhost), which keeps the watch HTTP relay policy.
For a plain-LAN setup without Tailscale, put an HTTPS proxy in front of
`dev_ota.py serve --host 0.0.0.0`.

## Use

The watch reports its git sha (`APP_BUILD_VERSION`), and the app checks it
against the published commit. Zephyr only regenerates that header when
`app/VERSION` changes, so delete it before building a new commit:
`rm app/build_dbg/app/zephyr/include/generated/zephyr/app_version.h`.

```sh
# after building and smoke-testing on the dev kit
scripts/dev_ota/dev_ota.py publish ZSWatch/app/build_dbg/dfu_application.zip \
  --repo ZSWatch --note "What changed"
scripts/dev_ota/dev_ota.py status --wait <id>   # exit 0 = running on the watch
```

`publish` also builds the resource image (`lvgl_resources_raw.bin` from the
firmware repo's `app/src/images/binaries/S/`) and includes it when it differs
from the one the watch last got through dev OTA (`--resources auto`, default;
`always` / `never` override). With resources, the package is a release-style
zip (`dfu_application.zip` + `lvgl_resources_raw.bin`) and the app uploads the
resources before the firmware. `--repo` must point at the firmware repo.

The app shows a dialog for each new build while it is open. When it is not,
the companion service (if running) long-polls too and posts a notification.
Tapping it opens the app; its **Install** button installs the build in the
background through the native firmware owner, shows progress in the
notification and reports the same states. In the app dialog, **Install** runs
the normal firmware update (resources first, then firmware) and opens the
firmware screen; **Not now** skips that build. The app reports
`downloading`, `uploading`, `completed`, then `running` (watch reconnected and
reports the published sha), `mismatch` (it reports another sha), or `failed` /
`cancelled` / `declined`.

**Heart rate (HR) variant:** the driver is the west module `Zephyr-MAX32664C`
(pinned in `ZSWatch/app/west.yml`), and the local NCS has the upstream driver
patched out. Without the module the build silently drops the driver (Kconfig
warning only). Clone it to `ZSWatch/modules/lib/max32664c` at the pinned commit
and pass `-DZEPHYR_EXTRA_MODULES=$PWD/modules/lib/max32664c`; check
`CONFIG_SENSOR_MAX32664C=y` in `app/zephyr/.config`.

**Smoke-test on the dev kit before publishing.** The watch uses MCUboot
overwrite-only, so a build that cannot come back on BLE has no automatic
rollback and needs USB to recover.

## API

All requests need `Authorization: Bearer <token>`. Paths may have any prefix.

| Request | |
| --- | --- |
| `GET /api/latest?after=<id>&wait=<s>` | `{"build": manifest or null}`; waits up to 30 s for a build other than `after` |
| `GET /api/builds/<id>.zip` | the firmware package (last 10 kept) |
| `POST /api/status` | `{"id", "state", "detail"?}`, appended to `status.jsonl` |
| `GET /api/status` | last 20 statuses |
| `GET /files/<name>` | **no token**: files in `~/.zswatch_dev_ota/files/`, e.g. an APK to open in the phone browser. Only reachable on the tailnet. |

Data lives in `~/.zswatch_dev_ota/` (`ZSWATCH_DEV_OTA_DIR` overrides).
