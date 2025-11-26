# Gadgetbridge API Contract

**Branch**: `001-companion-app` | **Date**: 2025-11-26

## Overview

The Gadgetbridge API is the primary communication protocol between the ZSWatch companion app and the watch. Based on the [Espruino Gadgetbridge](https://www.espruino.com/Gadgetbridge) specification, this is a well-established protocol that provides comprehensive smartwatch functionality.

## Transport

- **Characteristic**: Nordic UART Service (NUS)
  - Service UUID: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
  - TX Characteristic: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` (Write - App to Watch)
  - RX Characteristic: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` (Notify - Watch to App)
- **Encoding**: JSON wrapped in `GB({...})` or plain commands
- **Framing**: Messages prefixed with `\x10` + `GB(...)\n` internally

---

## Messages: Phone → Watch

### Set Time

```javascript
setTime(<unix_timestamp_seconds>);E.setTimeZone(<offset_hours>);
```

**Example**:
```javascript
setTime(1700556601);E.setTimeZone(1.0);
```

### Notification

```javascript
GB({"t":"notify","id":<int>,"src":"<app>","title":"<title>","body":"<body>","sender":"<sender>","tel":"<phone>","reply":<bool>})
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `t` | string | Yes | `"notify"` |
| `id` | integer | Yes | Unique notification ID |
| `src` | string | Yes | Source app name |
| `title` | string | No | Notification title |
| `body` | string | No | Notification body |
| `sender` | string | No | Sender name |
| `subject` | string | No | Email subject |
| `tel` | string | No | Phone number (for calls/SMS) |
| `reply` | boolean | No | If true, reply action available |

### Notification Update

```javascript
GB({"t":"notify~","id":<int>,"body":"<updated>"})
```

### Notification Remove

```javascript
GB({"t":"notify-","id":<int>})
```

### Alarm

```javascript
GB({"t":"alarm","d":[{"h":<hour>,"m":<minute>,"rep":<weekday_mask>,"on":<0|1>}]})
```

- `rep`: Binary mask of weekdays (bit 0 = Sunday, bit 6 = Saturday, 127 = every day)
- `on`: Optional, alarm enabled (default) or disabled

### Find Device

```javascript
GB({"t":"find","n":<true|false>})
```

### Vibrate

```javascript
GB({"t":"vibrate","n":<pattern_int>})
```

### Weather

```javascript
GB({"t":"weather","temp":<kelvin>,"hi":<high_k>,"lo":<low_k>,"hum":<percent>,"rain":<precip_prob>,"uv":<index>,"code":<condition>,"txt":"<desc>","wind":<m/s>,"wdir":<degrees>,"loc":"<location>"})
```

### Music State

```javascript
GB({"t":"musicstate","state":"<play|pause>","position":<seconds>,"shuffle":<0|1>,"repeat":<0|1>})
```

### Music Info

```javascript
GB({"t":"musicinfo","artist":"<artist>","album":"<album>","track":"<track>","dur":<seconds>,"c":<count>,"n":<number>})
```

### Call

```javascript
GB({"t":"call","cmd":"<accept|incoming|outgoing|reject|start|end>","name":"<name>","number":"<phone>"})
```

### Activity Tracking Control

```javascript
GB({"t":"act","hrm":<bool>,"stp":<bool>,"int":<seconds>})
```

Enable/disable realtime heart rate (`hrm`) and step counting (`stp`). `int` is report interval.

### Activity Fetch Request

```javascript
GB({"t":"actfetch","ts":<ms_since_1970>})
```

Request activity data since timestamp. If 0, watch sends all data.

### Recorder Log List Request

```javascript
GB({"t":"listRecs","id":"<YYYYMMDDx>"})
```

Request list of recorder logs newer than specified ID.

### Recorder Log Fetch

```javascript
GB({"t":"fetchRec","id":"<YYYYMMDDx>"})
```

Fetch specific recorder log.

### GPS Data

```javascript
GB({"t":"gps","lat":<float>,"lon":<float>,"alt":<float>,"speed":<kph>,"course":<deg>,"time":<ms>,"satellites":<int>,"hdop":<float>,"externalSource":true,"gpsSource":"<GPS|network>"})
```

### GPS Active Query

```javascript
GB({"t":"is_gps_active"})
```

Causes watch to respond with `gps_power` status.

### Calendar Event

```javascript
GB({"t":"calendar","id":<int>,"type":<int>,"timestamp":<sec>,"durationInSeconds":<int>,"title":"<title>","description":"<desc>","location":"<loc>","calName":"<name>","color":<int>,"allDay":<bool>})
```

### Calendar Remove

```javascript
GB({"t":"calendar-","id":<int>})
```

### Force Calendar Sync

```javascript
GB({"t":"force_calendar_sync_start"})
```

### Navigation

```javascript
GB({"t":"nav","instr":"<instruction>","distance":"<dist>","action":"<action>","eta":"<time>"})
```

### Navigation Stop

```javascript
GB({"t":"nav"})
```

### HTTP Response

```javascript
GB({"t":"http","resp":"<json_string>","id":"<request_id>"})
GB({"t":"http","err":"<error_message>"})
```

---

## Messages: Watch → Phone

### Firmware/Hardware Version (sent at connect)

```javascript
{"t":"ver","fw":"<firmware_version>","hw":"<hardware_version>"}
```

### Status Update

```javascript
{"t":"status","bat":<0-100>,"volt":<float>,"chg":<0|1>}
```

### Music Control

```javascript
{"t":"music","n":"<play|pause|next|previous|volumeup|volumedown>"}
```

### Find Phone

```javascript
{"t":"findPhone","n":<true|false>}
```

### Call Control

```javascript
{"t":"call","n":"<ACCEPT|END|INCOMING|OUTGOING|REJECT|START|IGNORE>"}
```

### Notification Action

```javascript
{"t":"notify","id":<int>,"n":"<DISMISS|DISMISS_ALL|OPEN|MUTE|REPLY>"}
{"t":"notify","id":<int>,"n":"REPLY","msg":"<reply_text>","tel":"<phone>"}
```

### Activity Data

```javascript
{"t":"act","ts":<ms>,"hrm":<bpm>,"stp":<steps>,"mov":<intensity>,"act":"<activity_type>","rt":<bool>}
```

- `ts`: Optional timestamp (ms since 1970), defaults to current time
- `act`: Optional activity type: `UNKNOWN`, `NOT_WORN`, `DEEP_SLEEP`, `LIGHT_SLEEP`, `REM_SLEEP`, `ACTIVITY`, `RUNNING`, `WALKING`, `SWIMMING`, `CYCLING`, `EXERCISE`
- `rt`: Optional, if true indicates realtime sample (not stored in DB)

### Activity Tracks List

```javascript
{"t":"actTrksList","list":"<comma_separated_ids>"}
```

### Activity Track Data

```javascript
{"t":"actTrk","log":"<YYYYMMDDx>","lines":"<data>","cnt":<packet_count>}
```

### Force Calendar Sync

```javascript
{"t":"force_calendar_sync","ids":[<int>,<int>,...]}
```

Sends list of existing calendar IDs, asks phone to sync differences.

### GPS Power Request

```javascript
{"t":"gps_power","status":<true|false>}
```

### HTTP Request

```javascript
{"t":"http","url":"<https_url>","id":"<request_id>","xpath":"<optional>","insecure":<bool>}
```

- `xpath`: Optional, apply XPath to XML response
- `insecure`: Optional, disable TLS validation (not recommended)

### Intent (Android)

```javascript
{"t":"intent","target":"<broadcastreceiver|activity|service|foregroundservice>","action":"<action>","flags":[...],"categories":[...],"package":"<pkg>","class":"<class>","mimetype":"<mime>","data":"<uri>","extra":{...}}
```

### File Write

```javascript
{"t":"file","n":"<filename>","c":"<contents>","m":"<a|w>"}
```

- `m`: `"a"` for append, `"w"` for overwrite

### Info/Warning/Error Popup

```javascript
{"t":"info","msg":"<message>"}
{"t":"warn","msg":"<message>"}
{"t":"error","msg":"<message>"}
```

---

## Character Encoding

The firmware uses a hybrid encoding approach:

- UTF-8 for standard ASCII
- Non-ASCII may appear as:
  - Raw bytes (0x80-0xFF) representing UTF-16 code units
  - Escape sequences: `\xNN`
  - Base64: `atob("...")`

The app must normalize all variants to proper UTF-8.

---

## Error Handling

- **Malformed JSON**: Log warning, discard
- **Unknown message type**: Log and ignore (forward compatibility)
- **Missing fields**: Use sensible defaults
- **Connection loss**: Queue messages for retry on reconnect

---

## Sequence Diagrams

### Connection Initialization

```
App                                      Watch
 │                                          │
 │  Connect + Bond                         │
 │─────────────────────────────────────────>│
 │                                          │
 │  {"t":"ver","fw":"1.2.3","hw":"5"}      │
 │<─────────────────────────────────────────│
 │                                          │
 │  setTime(...);E.setTimeZone(...)        │
 │─────────────────────────────────────────>│
 │                                          │
 │  {"t":"status","bat":85,"volt":4.1}     │
 │<─────────────────────────────────────────│
```

### Notification Flow (Android)

```
Phone                    App                     Watch
  │                       │                        │
  │ NotificationPosted    │                        │
  │──────────────────────>│                        │
  │                       │  GB({"t":"notify"...}) │
  │                       │───────────────────────>│
  │                       │                        │
  │                       │  {"t":"notify",...}    │
  │                       │<───────────────────────│
  │ Dismiss notification  │     (action)           │
  │<──────────────────────│                        │
```

### Music Control Flow

```
Watch                    App                     Phone
  │                       │                        │
  │ {"t":"music","n":"next"}                       │
  │──────────────────────>│                        │
  │                       │  MediaController.next()│
  │                       │───────────────────────>│
  │                       │                        │
  │                       │  onMetadataChanged()   │
  │                       │<───────────────────────│
  │  GB({"t":"musicinfo"})│                        │
  │<──────────────────────│                        │
```

### Activity Data Sync

```
App                                      Watch
 │                                          │
 │  GB({"t":"actfetch","ts":0})            │
 │─────────────────────────────────────────>│
 │                                          │
 │  {"t":"act","ts":...,"stp":1234,...}    │
 │<─────────────────────────────────────────│
 │  {"t":"act","ts":...,"stp":567,...}     │
 │<─────────────────────────────────────────│
 │  (continues until all data sent)         │
```
