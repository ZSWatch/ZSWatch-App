# Follow-ups

Agreed work that is not started yet.

## Firmware: overlay manager

Overlays (popups shown on top of the watchface or any app) are each special-cased
in `ui/zsw_ui_controller.c`: the back button, the main button and swipes check
`zsw_notification_popup_is_shown()`, `zsw_recording_overlay_is_shown()`,
`zsw_voice_memo_popup_is_shown()` and `zsw_chat_popup_is_shown()` one by one.
Every new overlay adds more checks, and each overlay repeats the same code for
`lv_layer_top()`, notification mode, input focus, waking the display and
auto-dismiss.

Proposal: a small overlay manager, separate from the app manager (apps are full
screen, one at a time and listed in the picker; overlays are short-lived, sit on
top of whatever runs and are triggered from BLE, timers or buttons).

- Overlays register themselves, like apps: name, priority, `show`/`close`,
  `back()` (returns whether it handled back) and whether it blocks gestures.
- The manager owns `lv_layer_top()`, notification mode and input focus, waking
  the display and auto-dismiss.
- The UI controller only calls `zsw_overlay_handle_back()` and
  `zsw_overlay_active()`; it no longer knows individual overlays.
- One overlay is visible at a time; a second one waits or replaces the first by
  priority.
- An app can still own an overlay (as Chat does) without the controller knowing.
- Migrate the notification popup, recording overlay, voice memo popup and Chat
  popup.
