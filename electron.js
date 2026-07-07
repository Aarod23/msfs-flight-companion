const { app, BrowserWindow, Tray, Menu, nativeImage, ipcMain, Notification } = require('electron');
const path = require('path');
const Store = require('electron-store');
const SimConnectBridge = require('./simconnect-bridge');
const SimBrief = require('./simbrief');
const RelayClient = require('./relay-client');

const store = new Store();

let mainWindow = null;
let tray = null;
let simBridge = null;
let relayClient = null;
let flightState = {
  connected: false,
  phase: 'PREFLIGHT',
  lat: 0, lon: 0, alt: 0,
  ias: 0, gs: 0, vs: 0, hdg: 0,
  onGround: true, fuel: 0,
  engineOn: false,
  simbrief: null,
  atd: null, blockOn: null,
  lastUpdated: null
};

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 900,
    minHeight: 600,
    backgroundColor: '#0a0e1a',
    titleBarStyle: 'hiddenInset',
    frame: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    },
    icon: path.join(__dirname, 'assets', 'icon.png'),
    show: false
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));

  mainWindow.once('ready-to-show', () => mainWindow.show());

  mainWindow.on('close', (e) => {
    e.preventDefault();
    mainWindow.hide();
  });
}

function createTray() {
  const icon = nativeImage.createFromPath(path.join(__dirname, 'assets', 'tray-icon.png'));
  tray = new Tray(icon.resize({ width: 16, height: 16 }));

  const contextMenu = Menu.buildFromTemplate([
    { label: 'Show FlightCompanion', click: () => { mainWindow.show(); mainWindow.focus(); } },
    { type: 'separator' },
    {
      label: 'Load SimBrief Plan', click: async () => {
        const data = await SimBrief.fetchOFP();
        if (data) {
          flightState.simbrief = data;
          broadcastState();
          showNotification('SimBrief', `Loaded: ${data.origin.icao} → ${data.destination.icao}`);
        }
      }
    },
    { type: 'separator' },
    { label: 'Quit', click: () => { app.exit(0); } }
  ]);

  tray.setToolTip('MSFS Flight Companion');
  tray.setContextMenu(contextMenu);
  tray.on('double-click', () => { mainWindow.show(); mainWindow.focus(); });
}

function broadcastState() {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('flight-state', flightState);
  }
  if (relayClient) {
    relayClient.push(flightState);
  }
}

function detectPhase(prev) {
  const { onGround, engineOn, ias, gs, vs, alt, simbrief } = flightState;
  const cruiseAlt = simbrief ? parseInt(simbrief.cruiseAlt) : 35000;

  if (onGround && !engineOn) return 'PREFLIGHT';
  if (onGround && engineOn && gs < 80) return 'TAXI';
  if (onGround && gs >= 80) return 'TAKEOFF';
  if (!onGround && alt < 10000 && ias < 250 && vs < 0) return 'APPROACH';
  if (!onGround && vs > 200 && alt < cruiseAlt - 1000) return 'CLIMB';
  if (!onGround && Math.abs(alt - cruiseAlt) < 1500) return 'CRUISE';
  if (!onGround && vs < -200) return 'DESCENT';
  if (onGround && prev !== 'PREFLIGHT' && prev !== 'TAXI') return 'LANDED';
  return prev;
}

function onSimData(data) {
  const prevPhase = flightState.phase;
  const wasOnGround = flightState.onGround;

  Object.assign(flightState, data, { connected: true, lastUpdated: Date.now() });
  flightState.phase = detectPhase(prevPhase);

  // Detect actual time of departure
  if (wasOnGround && !flightState.onGround && flightState.ias > 30) {
    if (!flightState.atd) {
      flightState.atd = Date.now();
      showNotification('✈️ Departed', `Block off recorded`);
    }
  }

  // Detect landing
  if (!wasOnGround && flightState.onGround && prevPhase === 'APPROACH') {
    flightState.blockOn = Date.now();
    showNotification('🏁 Landed', `Block on recorded`);
  }

  // Phase change notifications
  if (prevPhase !== flightState.phase) {
    handlePhaseChange(prevPhase, flightState.phase);
  }

  broadcastState();
}

function handlePhaseChange(prev, next) {
  const messages = {
    CLIMB: '🔝 Climbing to cruise altitude',
    CRUISE: `🛫 Reached cruise altitude`,
    DESCENT: '🛬 Beginning descent — prepare for arrival',
    APPROACH: '⏰ On approach',
    LANDED: '🏁 Gear down — welcome to your destination'
  };
  if (messages[next]) showNotification('Flight Phase', messages[next]);
}

function showNotification(title, body) {
  new Notification({ title, body, silent: false }).show();
}

// IPC Handlers
ipcMain.handle('get-state', () => flightState);

ipcMain.handle('load-simbrief', async () => {
  const data = await SimBrief.fetchOFP();
  if (data) {
    flightState.simbrief = data;
    broadcastState();
  }
  return data;
});

ipcMain.handle('get-settings', () => store.store);
ipcMain.handle('save-settings', (_, settings) => store.set(settings));

// App lifecycle
app.whenReady().then(() => {
  createWindow();
  createTray();

  // Start SimConnect bridge
  simBridge = new SimConnectBridge(onSimData, (connected) => {
    flightState.connected = connected;
    tray.setToolTip(connected ? 'MSFS Flight Companion — Connected' : 'MSFS Flight Companion — Waiting for MSFS');
    broadcastState();
    if (connected) showNotification('MSFS Connected', 'SimConnect link established');
  });
  simBridge.start();

  // Start relay client
  const relayUrl = store.get('relayUrl', 'https://msfs-relay.onrender.com');
  const relayKey = store.get('relayKey', 'default-key');
  relayClient = new RelayClient(relayUrl, relayKey);

  // Broadcast state every 5s even if no new sim data
  setInterval(broadcastState, 5000);
});

app.on('window-all-closed', (e) => e.preventDefault());
app.on('before-quit', () => {
  if (simBridge) simBridge.stop();
});
