const { open, SimConnectPeriod, SimConnectDataType, Protocol, SimObjectType } = require('node-simconnect');

// ── User aircraft data definition ──────────────────────────────────────────
const USER_DEFINE_ID  = 1;
const USER_REQUEST_ID = 1;

const USER_VARS = [
  { name: 'PLANE LATITUDE',               unit: 'degrees',         key: 'lat',       type: SimConnectDataType.FLOAT64 },
  { name: 'PLANE LONGITUDE',              unit: 'degrees',         key: 'lon',       type: SimConnectDataType.FLOAT64 },
  { name: 'PLANE ALTITUDE',               unit: 'feet',            key: 'alt',       type: SimConnectDataType.FLOAT64 },
  { name: 'AIRSPEED INDICATED',           unit: 'knots',           key: 'ias',       type: SimConnectDataType.FLOAT64 },
  { name: 'AIRSPEED TRUE',                unit: 'knots',           key: 'tas',       type: SimConnectDataType.FLOAT64 },
  { name: 'GROUND VELOCITY',              unit: 'knots',           key: 'gs',        type: SimConnectDataType.FLOAT64 },
  { name: 'PLANE HEADING DEGREES TRUE',   unit: 'degrees',         key: 'hdg',       type: SimConnectDataType.FLOAT64 },
  { name: 'VERTICAL SPEED',               unit: 'feet per minute', key: 'vs',        type: SimConnectDataType.FLOAT64 },
  { name: 'SIM ON GROUND',                unit: 'bool',            key: 'onGround',  type: SimConnectDataType.INT32   },
  { name: 'FUEL TOTAL QUANTITY',          unit: 'gallons',         key: 'fuel',      type: SimConnectDataType.FLOAT64 },
  { name: 'GENERAL ENG COMBUSTION:1',     unit: 'bool',            key: 'engineOn',  type: SimConnectDataType.INT32   },
  { name: 'AMBIENT WIND VELOCITY',        unit: 'knots',           key: 'windSpeed', type: SimConnectDataType.FLOAT64 },
  { name: 'AMBIENT WIND DIRECTION',       unit: 'degrees',         key: 'windDir',   type: SimConnectDataType.FLOAT64 },
];

// ── AI Traffic data definition ──────────────────────────────────────────────
const AI_DEFINE_ID  = 2;
const AI_REQUEST_ID = 2;
const AI_RADIUS_METERS = 150000; // 150km radius

const AI_VARS_NUMERIC = [
  { name: 'PLANE LATITUDE',               unit: 'degrees',         key: 'lat',      type: SimConnectDataType.FLOAT64 },
  { name: 'PLANE LONGITUDE',              unit: 'degrees',         key: 'lon',      type: SimConnectDataType.FLOAT64 },
  { name: 'PLANE ALTITUDE',               unit: 'feet',            key: 'alt',      type: SimConnectDataType.FLOAT64 },
  { name: 'PLANE HEADING DEGREES TRUE',   unit: 'degrees',         key: 'hdg',      type: SimConnectDataType.FLOAT64 },
  { name: 'GROUND VELOCITY',              unit: 'knots',           key: 'gs',       type: SimConnectDataType.FLOAT64 },
  { name: 'SIM ON GROUND',                unit: 'bool',            key: 'onGround', type: SimConnectDataType.INT32   },
];

// String vars added separately (may fail on some SimConnect versions)
const AI_VARS_STRING = [
  { name: 'ATC ID',      key: 'callsign', readMethod: 'readString64', type: SimConnectDataType.STRING64 },
  { name: 'ATC MODEL',   key: 'model',    readMethod: 'readString64', type: SimConnectDataType.STRING64 },
  { name: 'ATC AIRLINE', key: 'airline',  readMethod: 'readString32', type: SimConnectDataType.STRING32 },
];

class SimConnectBridge {
  constructor(onData, onConnectionChange, onTrafficUpdate) {
    this.onData = onData;
    this.onConnectionChange = onConnectionChange;
    this.onTrafficUpdate = onTrafficUpdate || null;
    this.handle = null;
    this.retryTimer = null;
    this.running = false;
    this.trafficMap = new Map();      // objectId → traffic data
    this.trafficPollTimer = null;
    this.hasStringDefs = false;
  }

  start() {
    this.running = true;
    this._connect();
  }

  stop() {
    this.running = false;
    if (this.retryTimer) clearTimeout(this.retryTimer);
    if (this.trafficPollTimer) clearInterval(this.trafficPollTimer);
    if (this.handle) {
      try { this.handle.close(); } catch (_) {}
    }
  }

  getTraffic() {
    return Array.from(this.trafficMap.values());
  }

  async _connect() {
    if (!this.running) return;

    try {
      const { recvOpen, handle } = await open('MSFSFlightCompanion', Protocol.FSX_SP2);
      console.log('[SimConnect] Connected to:', recvOpen.applicationName);
      this.handle = handle;
      this.onConnectionChange(true);

      // ── Register user aircraft data definition ──
      USER_VARS.forEach(v => {
        handle.addToDataDefinition(USER_DEFINE_ID, v.name, v.unit, v.type);
      });

      // ── Register AI traffic data definition (numeric) ──
      AI_VARS_NUMERIC.forEach(v => {
        handle.addToDataDefinition(AI_DEFINE_ID, v.name, v.unit, v.type);
      });

      // ── Try to register string variables ──
      try {
        AI_VARS_STRING.forEach(v => {
          handle.addToDataDefinition(AI_DEFINE_ID, v.name, null, v.type);
        });
        this.hasStringDefs = true;
        console.log('[SimConnect] AI string vars registered');
      } catch (e) {
        console.warn('[SimConnect] AI string vars not supported:', e.message);
      }

      // ── Request user aircraft data every second ──
      handle.requestDataOnSimObject(
        USER_REQUEST_ID, USER_DEFINE_ID,
        0, // user object
        SimConnectPeriod.SECOND,
        0, 0, 0, 0
      );

      // ── Start AI traffic polling ──
      this._pollTraffic();
      this.trafficPollTimer = setInterval(() => this._pollTraffic(), 5000);

      // ── Event handlers ──
      handle.on('simObjectData', (recvData) => {
        if (recvData.requestID === USER_REQUEST_ID) {
          this._parseUserData(recvData.data);
        } else if (recvData.requestID === AI_REQUEST_ID) {
          this._parseTrafficData(recvData.objectID, recvData.data);
        }
      });

      handle.on('exception', (ex) => {
        console.warn('[SimConnect] Exception:', ex.exception, ex.sendID);
      });

      handle.on('close', () => {
        console.log('[SimConnect] Connection closed');
        this._onDisconnect();
      });

      handle.on('error', (err) => {
        console.error('[SimConnect] Error:', err.message);
        this._onDisconnect();
      });

    } catch (err) {
      console.log(`[SimConnect] Not connected (${err.message}) — retry in 5s`);
      this._scheduleRetry();
    }
  }

  _onDisconnect() {
    this.handle = null;
    if (this.trafficPollTimer) { clearInterval(this.trafficPollTimer); this.trafficPollTimer = null; }
    this.trafficMap.clear();
    this.onConnectionChange(false);
    this._scheduleRetry();
  }

  _pollTraffic() {
    if (!this.handle) return;
    try {
      // Mark all existing traffic as potentially stale
      const now = Date.now();
      // Request all aircraft within radius
      this.handle.requestDataOnSimObjectType(
        AI_REQUEST_ID,
        AI_DEFINE_ID,
        AI_RADIUS_METERS,
        SimObjectType.AIRCRAFT
      );
      // Prune stale entries (not seen in 15 seconds)
      for (const [id, entry] of this.trafficMap) {
        if (now - entry.lastSeen > 15000) {
          this.trafficMap.delete(id);
        }
      }
      // Emit updated traffic list
      if (this.onTrafficUpdate) {
        this.onTrafficUpdate(this.getTraffic());
      }
    } catch (e) {
      console.warn('[SimConnect] Traffic poll failed:', e.message);
    }
  }

  _parseUserData(buf) {
    const data = {};
    try {
      for (const v of USER_VARS) {
        if (v.type === SimConnectDataType.INT32) {
          data[v.key] = Boolean(buf.readInt32());
        } else {
          const raw = buf.readFloat64();
          data[v.key] = parseFloat(raw.toFixed(6));
        }
      }
      this.onData(data);
    } catch (e) {
      console.error('[SimConnect] User data parse error:', e.message);
    }
  }

  _parseTrafficData(objectId, buf) {
    try {
      const data = { objectId, lastSeen: Date.now() };

      // Numeric fields
      for (const v of AI_VARS_NUMERIC) {
        if (v.type === SimConnectDataType.INT32) {
          data[v.key] = Boolean(buf.readInt32());
        } else {
          data[v.key] = parseFloat(buf.readFloat64().toFixed(6));
        }
      }

      // String fields (best effort)
      if (this.hasStringDefs) {
        try {
          data.callsign = (buf.readString64() || '').replace(/\0/g, '').trim();
          data.model    = (buf.readString64() || '').replace(/\0/g, '').trim();
          data.airline  = (buf.readString32() || '').replace(/\0/g, '').trim();
        } catch (_) {
          data.callsign = '';
          data.model    = 'UNKN';
          data.airline  = '';
        }
      } else {
        data.callsign = `AI-${objectId}`;
        data.model    = 'UNKN';
        data.airline  = '';
      }

      // Skip user aircraft (objectId = 0) and ground vehicles
      if (objectId === 0) return;

      this.trafficMap.set(objectId, data);
    } catch (e) {
      // Silently skip malformed packets
    }
  }

  _scheduleRetry() {
    if (!this.running) return;
    if (this.retryTimer) clearTimeout(this.retryTimer);
    this.retryTimer = setTimeout(() => this._connect(), 5000);
  }
}

module.exports = SimConnectBridge;
