const { open, SimConnectPeriod, SimConnectDataType, Protocol } = require('node-simconnect');

const SIM_VARS = [
  { name: 'PLANE LATITUDE',               unit: 'degrees',         key: 'lat',      type: SimConnectDataType.FLOAT64 },
  { name: 'PLANE LONGITUDE',              unit: 'degrees',         key: 'lon',      type: SimConnectDataType.FLOAT64 },
  { name: 'PLANE ALTITUDE',               unit: 'feet',            key: 'alt',      type: SimConnectDataType.FLOAT64 },
  { name: 'AIRSPEED INDICATED',           unit: 'knots',           key: 'ias',      type: SimConnectDataType.FLOAT64 },
  { name: 'AIRSPEED TRUE',                unit: 'knots',           key: 'tas',      type: SimConnectDataType.FLOAT64 },
  { name: 'GROUND VELOCITY',              unit: 'knots',           key: 'gs',       type: SimConnectDataType.FLOAT64 },
  { name: 'PLANE HEADING DEGREES TRUE',   unit: 'degrees',         key: 'hdg',      type: SimConnectDataType.FLOAT64 },
  { name: 'VERTICAL SPEED',               unit: 'feet per minute', key: 'vs',       type: SimConnectDataType.FLOAT64 },
  { name: 'SIM ON GROUND',                unit: 'bool',            key: 'onGround', type: SimConnectDataType.INT32   },
  { name: 'FUEL TOTAL QUANTITY',          unit: 'gallons',         key: 'fuel',     type: SimConnectDataType.FLOAT64 },
  { name: 'GENERAL ENG COMBUSTION:1',     unit: 'bool',            key: 'engineOn', type: SimConnectDataType.INT32   },
];

const DEFINE_ID = 1;
const REQUEST_ID = 1;

class SimConnectBridge {
  constructor(onData, onConnectionChange) {
    this.onData = onData;
    this.onConnectionChange = onConnectionChange;
    this.connection = null;
    this.retryTimer = null;
    this.running = false;
  }

  start() {
    this.running = true;
    this._connect();
  }

  stop() {
    this.running = false;
    if (this.retryTimer) clearTimeout(this.retryTimer);
    if (this.connection) {
      try { this.connection.close(); } catch (_) {}
    }
  }

  async _connect() {
    if (!this.running) return;

    try {
      const { recvOpen, handle } = await open('MSFSFlightCompanion', Protocol.FSX_SP2);
      console.log('[SimConnect] Connected to:', recvOpen.applicationName);
      this.connection = handle;
      this.onConnectionChange(true);

      // Register data definition
      SIM_VARS.forEach((v, idx) => {
        handle.addToDataDefinition(DEFINE_ID, v.name, v.unit, v.type);
      });

      // Request periodic updates (once per second)
      handle.requestDataOnSimObject(
        REQUEST_ID,
        DEFINE_ID,
        0,                          // SIMCONNECT_OBJECT_ID_USER
        SimConnectPeriod.SECOND,
        0, 0, 0, 0
      );

      handle.on('simObjectData', (recvData) => {
        if (recvData.requestID !== REQUEST_ID) return;
        try {
          const data = {};
          for (const v of SIM_VARS) {
            if (v.type === SimConnectDataType.INT32) {
              data[v.key] = Boolean(recvData.data.readInt32());
            } else {
              const raw = recvData.data.readFloat64();
              data[v.key] = parseFloat(raw.toFixed(5));
            }
          }
          this.onData(data);
        } catch (e) {
          console.error('[SimConnect] Parse error:', e.message);
        }
      });

      handle.on('exception', (ex) => {
        console.warn('[SimConnect] SimConnect exception:', ex.exception);
      });

      handle.on('close', () => {
        console.log('[SimConnect] Connection closed');
        this.connection = null;
        this.onConnectionChange(false);
        this._scheduleRetry();
      });

      handle.on('error', (err) => {
        console.error('[SimConnect] Error:', err.message);
        this.connection = null;
        this.onConnectionChange(false);
        this._scheduleRetry();
      });

    } catch (err) {
      console.log(`[SimConnect] Not connected (${err.message}) — retry in 5s`);
      this._scheduleRetry();
    }
  }

  _scheduleRetry() {
    if (!this.running) return;
    if (this.retryTimer) clearTimeout(this.retryTimer);
    this.retryTimer = setTimeout(() => this._connect(), 5000);
  }
}

module.exports = SimConnectBridge;
