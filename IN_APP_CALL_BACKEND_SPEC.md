# StreetRide — In-App Call Feature: Backend Requirements

## Overview

We want to add in-app voice calling between riders and drivers (similar to Uber's in-app call).  
The mobile app will use **Agora RTC** for the actual audio stream.  
The backend is responsible for **signaling** (letting the other party know a call is coming) and **Agora token generation**.

---

## How It Works (End to End)

1. Rider or driver taps the call button on the active ride screen.
2. The app sends a request to the backend: `"I am calling the other party on ride [reqId]"`.
3. The backend stores the call status against that ride request.
4. The other party's app polls the backend every 4 seconds (already doing this via BK8).
5. Their app detects the incoming call status and shows an incoming call screen.
6. Both parties join an Agora audio channel named after the `reqId`.
7. When either party hangs up or declines, the app sends a request to clear the call status.

---

## What the Backend Needs to Add

### 1. Call Status Field on BK8 Response

The existing `BK8` endpoint already returns ride messages. We need one new field added to each message object:

```json
{
  "reqid": "abc123",
  "dphone": "2348012345678",
  "rphone": "2348087654321",
  ...existing fields...,
  "CallStatus": "idle"
}
```

**Possible values for `CallStatus`:**

| Value | Meaning |
|---|---|
| `idle` | No active call (default) |
| `calling_driver` | Rider is calling the driver |
| `calling_rider` | Driver is calling the rider |
| `in_call` | Both parties connected |
| `declined` | The callee declined |
| `ended` | Call was ended |

---

### 2. New Endpoint — Initiate / Update Call Status

**Key:** `BK_CALL` (or whatever naming convention suits your system)

**Request body:**
```json
{
  "theKey": "BK_CALL",
  "reqid": "abc123",
  "status": "calling_driver"
}
```

**What it does:** Updates the `CallStatus` field for that ride request so the other party's poll detects it.

**Response (success):**
```json
{
  "status": "success"
}
```

The app will call this endpoint with these status values:

| App action | Status sent |
|---|---|
| Rider taps Call button | `calling_driver` |
| Driver taps Call button | `calling_rider` |
| Either party picks up | `in_call` |
| Either party declines | `declined` |
| Either party hangs up | `ended` |

---

### 3. New Endpoint — Agora Token Generation

The app needs a short-lived Agora RTC token to join the audio channel securely.

**Key:** `BK_AGORA_TOKEN` (or your preferred key)

**Request body:**
```json
{
  "theKey": "BK_AGORA_TOKEN",
  "reqid": "abc123",
  "phone": "2348012345678"
}
```

**What it does:**
- Uses your Agora **App ID** and **App Certificate** (stored securely on the server) to generate a token.
- The Agora channel name will be the `reqid`.
- The token expires after **1 hour** (or less — Agora supports configurable expiry).

**Response:**
```json
{
  "appId": "your_agora_app_id",
  "token": "006xxxxxxxxxxxxxxxx",
  "channel": "abc123",
  "uid": 0
}
```

> **Note:** The Agora App ID and App Certificate must never be exposed to the mobile app directly. The token must be generated server-side using the official Agora token builder library (available for Node.js, Python, PHP, Go, Java, etc.).  
> Agora token builder: https://github.com/AgoraIO/Tools/tree/master/DynamicKey/AgoraDynamicKey

---

## Agora Account Setup (One-Time)

1. Create a free account at https://console.agora.io
2. Create a new project — select **"Secured mode"** (token enabled)
3. Copy the **App ID** and **App Certificate** — store them in your server environment variables
4. The free tier includes **10,000 minutes/month** of audio calling at no cost

---

## Summary of Changes Required

| # | Change | Where |
|---|---|---|
| 1 | Add `CallStatus` field to BK8 response | Existing BK8 endpoint |
| 2 | New endpoint to update call status | New: `BK_CALL` |
| 3 | New endpoint to generate Agora token | New: `BK_AGORA_TOKEN` |
| 4 | Agora account + App ID + App Certificate | Agora console (one-time) |

---

## Notes

- The mobile app handles **all UI** (calling screen, incoming call screen, active call screen).
- The mobile app handles **all Agora SDK integration** — the backend only needs to generate the token.
- Calls are **audio only** (no video) for this phase.
- The `reqid` is used as the Agora channel name — this ensures rider and driver always join the same channel for their specific ride.
- Only rides with an **active status** (accepted, driver started, arrived, in transit) should allow calling — the app will enforce this.
- The backend does **not** need to handle WebSockets or long-polling — the existing 4-second poll interval is sufficient for call signaling.
