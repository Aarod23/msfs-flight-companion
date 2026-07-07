# MSFS Flight Companion

A real-time flight tracker for **MSFS 2024** with native iOS app, Dynamic Island Live Activity, and push notifications.

---

## Architecture

```
Windows PC (Electron app)
  ↓ HTTPS every 5s
Cloud Relay Server (Render.com)
  ↓ WebSocket live push
iPhone App (Swift/SwiftUI)
  → Dynamic Island
  → Push Notifications
```

---

## Quick Start

### 1. Desktop App (Windows)
```bash
cd FlightApp
npm install
npm start
```
Launches to system tray. Connect MSFS 2024, then click "Load SimBrief Plan".

### 2. Relay Server (one-time deploy)
1. Go to [render.com](https://render.com) → New → Web Service
2. Connect your GitHub repo (push the `server/` folder)
3. Build command: `npm install`
4. Start command: `node server.js`
5. Set env var `RELAY_API_KEY` to any secret string
6. Copy the deployed URL (e.g. `https://msfs-relay.onrender.com`)

### 3. iOS App (on Mac via Xcode)
1. Open `ios/FlightCompanion/` in Xcode
2. Add a **Widget Extension** target named `FlightLiveActivityWidget`
3. Copy `FlightLiveActivity.swift` into the widget target
4. Set your Apple ID in Signing & Capabilities
5. Enable **Push Notifications** and **Live Activities** capabilities
6. Build & run to your iPhone 17
7. Enter your relay server URL in Settings

### 4. AltStore (keep app installed)
- Install [AltServer](https://altstore.io) on your Windows PC
- Install AltStore on your iPhone via AltServer
- Enable Background Refresh in AltStore
- AltServer auto-refreshes the signing every 7 days while your PC is on

---

## SimBrief
Your Pilot ID **1246391** is hardcoded in `simbrief.js`.  
Click **"Load SimBrief Plan"** on the desktop app after filing your OFP.

---

## Features
- ✈️ **Live map** with animated aircraft, route line, and breadcrumb trail
- 📊 **Phase progress bar** (PREFLIGHT → TAXI → CLIMB → CRUISE → DESCENT → APPROACH → LANDED)
- ⏱️ **STD / ATD / STA / ETA** times with delay calculation
- ⏳ **Time remaining** with great-circle + ground speed ETA
- 🛢️ **Fuel gauge** vs. planned trip fuel
- 🔔 **Phase-change notifications** (local) on iOS
- 🏝️ **Dynamic Island** Live Activity with compact/expanded/minimal states
- 🖥️ **Desktop companion** (Electron) in Windows system tray
- ☁️ **Cloud relay** bridges PC → iPhone over the internet

---

## Flight Phases
| Phase | Condition |
|---|---|
| PREFLIGHT | Engines off, on ground |
| TAXI | Engines on, GS < 80kts |
| TAKEOFF | On ground, GS ≥ 80kts |
| CLIMB | Airborne, VS > +200fpm |
| CRUISE | Within 1,500ft of planned cruise |
| DESCENT | Airborne, VS < -200fpm |
| APPROACH | Alt < 10,000ft, IAS < 250kts |
| LANDED | Back on ground after flight |
