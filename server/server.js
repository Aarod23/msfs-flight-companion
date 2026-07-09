const express = require('express');
const cors = require('cors');
const { WebSocketServer } = require('ws');
const http = require('http');

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

const API_KEY = process.env.RELAY_API_KEY || 'flightapp2024';
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json({ limit: '2mb' }));

// ── In-memory state ────────────────────────────────────────────────────
let latestState = null;
let lastPcUpdate = null;
const connectedClients = new Set();

// ── Auth middleware ────────────────────────────────────────────────────
function requireKey(req, res, next) {
  const key = req.headers['x-api-key'] || req.query.key;
  if (key !== API_KEY) return res.status(401).json({ error: 'Unauthorized' });
  next();
}

// ── PC → Server: Push flight state ────────────────────────────────────
app.post('/state', requireKey, (req, res) => {
  latestState = req.body;
  lastPcUpdate = Date.now();

  // Broadcast to all connected WebSocket clients (iOS apps)
  const payload = JSON.stringify({ type: 'state', data: latestState });
  connectedClients.forEach(ws => {
    if (ws.readyState === 1) ws.send(payload);
  });

  res.json({ ok: true, clients: connectedClients.size });
});

// ── iOS App → Server: Get current state ───────────────────────────────
app.get('/state', (req, res) => {
  if (!latestState) return res.json({ connected: false, phase: 'PREFLIGHT' });
  const stale = lastPcUpdate && (Date.now() - lastPcUpdate) > 30_000;
  res.json({ ...latestState, stale, serverTime: Date.now() });
});

// ── Health check ───────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    ok: true,
    lastUpdate: lastPcUpdate,
    clients: connectedClients.size,
    hasState: !!latestState
  });
});

// ── WebSocket: Live push to iOS app ───────────────────────────────────
wss.on('connection', (ws, req) => {
  connectedClients.add(ws);
  console.log(`[WS] Client connected. Total: ${connectedClients.size}`);

  // Send current state immediately on connect
  if (latestState) {
    ws.send(JSON.stringify({ type: 'state', data: latestState }));
  } else {
    ws.send(JSON.stringify({ type: 'waiting', message: 'Waiting for simulator' }));
  }

  ws.on('close', () => {
    connectedClients.delete(ws);
    console.log(`[WS] Client disconnected. Total: ${connectedClients.size}`);
  });

  ws.on('error', () => connectedClients.delete(ws));
});

server.listen(PORT, () => {
  console.log(`✈ MSFS Relay Server running on port ${PORT}`);
  console.log(`  API Key: ${API_KEY}`);
});
