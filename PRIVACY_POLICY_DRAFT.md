# Privacy Policy

Draft update for https://zswatch.dev/privacy (the URL in App Store Connect and Play Console). Replace the page content and set the date.

Last updated: <date>

This Privacy Policy describes how the ZSWatch Companion App ("we", "us", or "our") collects, uses, and shares information when you use the app.

## Summary

- We do not run servers that collect your data. There are no accounts, analytics, ads, or tracking.
- Your data stays on your phone and your watch. It only leaves when a feature you turned on needs it, and only to the services listed below.

## Information the app handles

**Watch pairing.** The app stores your watch's Bluetooth identifier on your phone so it can reconnect.

**Health and activity data.** Steps, heart rate, battery, and similar data synced from the watch are stored on your phone only.

**Notifications.**
- On Android, if you grant notification access, the app forwards your phone's notifications to the watch. They are not stored or sent anywhere else.
- On iOS, the watch reads notifications directly from the phone through Apple's notification service.

**Location.**
- If you allow it, the app shares your location with the watch.
- The watch uses it to request weather and altitude data from Open-Meteo (api.open-meteo.com). The phone relays those requests, so your approximate coordinates are sent to Open-Meteo. No other identifier is attached.
- Background location keeps weather and GPS working when the app is closed.
- The app does not store a location history.

**Voice memos.**
- Recordings you make on the watch are copied to your phone and stored there.
- By default they are transcribed and summarized on your phone with on-device models. Nothing leaves the phone.
- If you add your own OpenRouter API key and agree to the prompt in the app, the audio, the transcript, and the text needed for summaries and Chat answers are sent to OpenRouter (openrouter.ai). OpenRouter then passes them to the AI model provider you selected. Their privacy policies apply: https://openrouter.ai/privacy
- You can delete recordings and transcripts in the app at any time.

**Calendar and reminders.** If you allow it, the app creates events, reminders, timers, and alarms that it found in your voice memos. It only adds items; it does not upload your calendar.

**Photos.** If you pick a photo as a watchface background, it is converted and sent to your watch. The app only gets the photo you pick.

**Watch apps that use the internet.**
- Some watch apps fetch data through the phone. Examples are weather and altitude (Open-Meteo) and trivia questions (opentdb.com).
- The phone only relays these HTTPS requests. It does not add personal data.

## Services the app connects to

| Service | Why | What is sent |
| --- | --- | --- |
| GitHub (github.com, api.github.com) | Firmware updates | Nothing personal; standard download requests |
| Hugging Face (huggingface.co) | Downloading on-device AI models | Nothing personal; standard download requests |
| Open-Meteo (api.open-meteo.com) | Weather and altitude on the watch | Approximate location |
| OpenRouter (openrouter.ai) | Only if you add your own key and agree | Voice memo audio and text, Chat questions |
| opentdb.com | Trivia watch app | Nothing personal |

We do not sell, trade, or share your information with anyone else.

## Permissions

| Permission | Purpose |
| --- | --- |
| Bluetooth | Communicate with your ZSWatch |
| Location (including background) | Weather and GPS for the watch, also when the app is closed |
| Notifications | Show timers, alarms, and the connection status |
| Notification access (Android) | Forward phone notifications to the watch |
| Calendar and reminders | Create items found in voice memos |
| Photos | Pick a watchface background |
| Internet | Firmware and model downloads, weather, and optional OpenRouter |

## Data storage and deletion

All app data is stored on your phone. To delete it, either use the delete options in the app or uninstall the app.

## Children's privacy

The app is not directed at children under 13. We do not knowingly collect information from children.

## Changes to this policy

Changes will be posted on this page with an updated date.

## Open source

The app is open source: https://github.com/ZSWatch/ZSWatch-App

## Contact

Open an issue on GitHub or email mail@zswatch.dev.
