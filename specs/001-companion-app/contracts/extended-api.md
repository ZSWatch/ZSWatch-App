# Extended ZSWatch API Contract

**Branch**: `001-companion-app` | **Date**: 2025-11-26

## Overview

The Extended ZSWatch API is a lightweight protocol for features not covered by Gadgetbridge. This API is minimal - most functionality uses Gadgetbridge API or existing GATT services.

**What Extended API handles**:
- Health data sync (bulk history fetch)
- Log streaming (developer tool)
- Shell commands (developer tool)
- Voice memo transfer (future placeholder)

**What Extended API does NOT handle** (use existing solutions):
- Device info → Gadgetbridge `t:"ver"` message
- Sensor streaming → Existing `zsw_gatt_sensor_server.c` GATT service
- Watch settings → Configured on watch directly
- Notifications/Music/Weather → Gadgetbridge API

## Transport

- **Primary Characteristic**: Custom ZSWatch Service
  - Service UUID: `12345678-1234-5678-1234-56789ABCDEF0` (TBD - coordinate with firmware)
  - TX Characteristic: `12345678-1234-5678-1234-56789ABCDEF1` (Write)
  - RX Characteristic: `12345678-1234-5678-1234-56789ABCDEF2` (Notify)
- **Encoding**: JSON over BLE (simpler than binary for debugging)
- **Fallback**: Can use NUS with `ZSWX:` prefix to distinguish from Gadgetbridge

---

## Message Format

Simple JSON messages. No complex binary headers needed since BLE guarantees delivery.

```json
{"type": "<message_type>", ...payload }
```

ACK/NACK only required for operations that can fail (e.g., enabling log streaming).

---

## Message Types

### health_sync: Health Data Sync

For bulk fetching historical health data not covered by Gadgetbridge `t:"act"` realtime updates.

**Request (Phone → Watch)**:
```json
{
  "type": "health_sync",
  "action": "fetch",
  "from": 1700556601,
  "to": 1700643001,
  "data_types": ["steps", "hr"]
}
```

**Response (Watch → Phone)**:
```json
{
  "type": "health_sync",
  "samples": [
    {"t": "steps", "v": 1234, "ts": 1700556601},
    {"t": "hr", "v": 72, "ts": 1700560201}
  ]
}
```

For large datasets, watch sends multiple response messages.

---

### log_stream: Log Streaming (Developer Tool)

**Start Streaming (Phone → Watch)**:
```json
{
  "type": "log_stream",
  "action": "start",
  "level": "debug"
}
```

**ACK (Watch → Phone)** - Required since this can fail:
```json
{
  "type": "log_stream",
  "status": "ok"
}
```

Or NACK:
```json
{
  "type": "log_stream",
  "status": "error",
  "error": "logging_disabled"
}
```

**Log Entry (Watch → Phone)**:
```json
{
  "type": "log",
  "level": "info",
  "module": "ble",
  "msg": "Connected to peer",
  "ts": 1700556601
}
```

**Stop Streaming (Phone → Watch)**:
```json
{
  "type": "log_stream",
  "action": "stop"
}
```

### voice_memo: Voice Memo Transfer (Placeholder)

**List Memos (Phone → Watch)**:
```json
{
  "type": "voice_memo",
  "action": "list"
}
```

**Memo List (Watch → Phone)**:
```json
{
  "type": "voice_memo",
  "memos": [
    {"id": "memo_001", "duration_ms": 5000, "ts": 1700556601}
  ]
}
```

**Fetch Memo (Phone → Watch)**:
```json
{
  "type": "voice_memo",
  "action": "fetch",
  "id": "memo_001"
}
```

**Memo Data (Watch → Phone)** - May be sent in chunks:
```json
{
  "type": "voice_memo",
  "id": "memo_001",
  "chunk": 1,
  "total_chunks": 3,
  "format": "opus",
  "data": "<base64_chunk>"
}
```

---

## Existing GATT Services (Not Extended API)

### Sensor Streaming

Raw sensor data uses the existing **zsw_gatt_sensor_server** implementation:

- **Service**: ZSWatch Sensor Service (see `zsw_gatt_sensor_server.c`)
- **Characteristics**:
  - Accelerometer data
  - Gyroscope data
  - PPG data
  - Temperature data
- **Protocol**: Standard GATT notify - subscribe to characteristic for streaming

The app subscribes to sensor characteristics directly via flutter_blue_plus. No custom protocol needed.

### Heart Rate

Standard Bluetooth Heart Rate Profile (GATT):
- Service UUID: `0x180D`
- Heart Rate Measurement: `0x2A37`

---

## Coexistence with Gadgetbridge

Messages are distinguished by transport:

| Protocol | Transport | Format |
|----------|-----------|--------|
| Gadgetbridge | NUS (Nordic UART) | `GB({...})` or `setTime(...)` |
| Extended API | Custom characteristic | `{"type": "..."}` |
| Sensor data | zsw_gatt_sensor_server | Binary GATT notify |
| Heart Rate | Standard HR GATT | Binary per BT spec |

The app's protocol service routes messages based on which characteristic they arrive on.

---

## Sequence Diagrams

### Health Data Sync

```
App                                      Watch
 │                                          │
 │  {"type":"health_sync","action":"fetch"} │
 │─────────────────────────────────────────>│
 │                                          │
 │  {"type":"health_sync","samples":[...]}  │
 │<─────────────────────────────────────────│
 │  (may receive multiple if large dataset) │
 │<─────────────────────────────────────────│
 │                                          │
 │  Store locally, update UI                │
```

### Sensor Streaming (via existing GATT)

```
App                                      Watch
 │                                          │
 │  Subscribe to accel characteristic       │
 │─────────────────────────────────────────>│
 │                                          │
 │  GATT Notify (accel data)               │
 │<─────────────────────────────────────────│
 │  GATT Notify (accel data)               │
 │<─────────────────────────────────────────│
 │  ...                                     │
 │                                          │
 │  Unsubscribe                            │
 │─────────────────────────────────────────>│
```

### Log Streaming

```
App                                      Watch
 │                                          │
 │  {"type":"log_stream","action":"start"}  │
 │─────────────────────────────────────────>│
 │                                          │
 │  {"type":"log_stream","status":"ok"}     │
 │<─────────────────────────────────────────│
 │                                          │
 │  {"type":"log","msg":"..."}             │
 │<─────────────────────────────────────────│
 │  {"type":"log","msg":"..."}             │
 │<─────────────────────────────────────────│
 │  ...                                     │
 │                                          │
 │  {"type":"log_stream","action":"stop"}   │
 │─────────────────────────────────────────>│
```
