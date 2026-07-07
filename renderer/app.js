/* ========================================
   MSFS Flight Companion — App Logic
   Renderer process: map, state, times
======================================== */

// ── State ──────────────────────────────────────────────────────────────
let state = {};
let map = null;
let aircraftMarker = null;
let routeLine = null;
let trailLine = null;
let trailCoords = [];
let originMarker = null, destMarker = null;
let tocMarker = null, todMarker = null;
let etaInterval = null;

// ── Map Init ───────────────────────────────────────────────────────────
function initMap() {
  map = L.map('map', {
    center: [30, 0],
    zoom: 3,
    zoomControl: true,
    attributionControl: true
  });

  // CartoDB Dark Matter tiles
  L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
    attribution: '© CartoDB © OpenStreetMap',
    subdomains: 'abcd',
    maxZoom: 18
  }).addTo(map);

  // Aircraft icon SVG
  createAircraftMarker(30, 0, 0);
}

function createAircraftIcon(heading) {
  // Realistic top-down commercial airliner (narrow-body style)
  // Nose points UP at heading 0, rotated by actual magnetic heading
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="44" height="44" viewBox="0 0 44 44">
      <defs>
        <filter id="ac-shadow">
          <feDropShadow dx="0" dy="0" stdDeviation="2.2" flood-color="rgba(255,255,255,0.4)"/>
        </filter>
      </defs>
      <g transform="rotate(${heading}, 22, 22)" filter="url(#ac-shadow)">
        <!-- Fuselage body -->
        <ellipse cx="22" cy="22" rx="2.6" ry="14" fill="white" opacity="0.97"/>
        <!-- Nose point -->
        <path d="M22 7 C20.4 9.5 19.6 11.5 22 12.5 C24.4 11.5 23.6 9.5 22 7Z" fill="white"/>
        <!-- Left main wing -->
        <path d="M20.2 19.5 L3.5 26.5 L4.2 29 L21 23.5Z" fill="white" opacity="0.94"/>
        <!-- Right main wing -->
        <path d="M23.8 19.5 L40.5 26.5 L39.8 29 L23 23.5Z" fill="white" opacity="0.94"/>
        <!-- Wing root fairing -->
        <ellipse cx="22" cy="21.5" rx="3.4" ry="2.4" fill="white"/>
        <!-- Left engine nacelle -->
        <rect x="7" y="25" width="6" height="2.5" rx="1.25" fill="white" opacity="0.82"/>
        <!-- Right engine nacelle -->
        <rect x="31" y="25" width="6" height="2.5" rx="1.25" fill="white" opacity="0.82"/>
        <!-- Left horizontal stabilizer -->
        <path d="M20.5 33.5 L12.5 38 L13.2 39.5 L21.3 35.5Z" fill="white" opacity="0.88"/>
        <!-- Right horizontal stabilizer -->
        <path d="M23.5 33.5 L31.5 38 L30.8 39.5 L22.7 35.5Z" fill="white" opacity="0.88"/>
        <!-- Tail cone -->
        <ellipse cx="22" cy="36" rx="1.5" ry="2.8" fill="white" opacity="0.92"/>
        <!-- Cockpit window dark tint -->
        <ellipse cx="22" cy="10.5" rx="1.1" ry="1.5" fill="rgba(10,10,10,0.5)"/>
        <!-- Fuselage centerline highlight for 3D depth -->
        <ellipse cx="21.6" cy="22" rx="0.7" ry="9.5" fill="rgba(255,255,255,0.18)"/>
      </g>
    </svg>`;
  return L.divIcon({
    html: svg,
    className: 'aircraft-marker-icon',
    iconSize: [44, 44],
    iconAnchor: [22, 22]
  });
}

function createAircraftMarker(lat, lon, heading) {
  if (aircraftMarker) aircraftMarker.remove();
  aircraftMarker = L.marker([lat, lon], { icon: createAircraftIcon(heading), zIndexOffset: 1000 })
    .addTo(map);
}

function updateAircraftMarker(lat, lon, heading) {
  if (!aircraftMarker) { createAircraftMarker(lat, lon, heading); return; }
  aircraftMarker.setLatLng([lat, lon]);
  aircraftMarker.setIcon(createAircraftIcon(heading));
}

function drawRoute(waypoints, origin, dest) {
  if (routeLine) routeLine.remove();

  const latlngs = [
    [origin.lat, origin.lon],
    ...waypoints.map(wp => [wp.lat, wp.lon]),
    [dest.lat, dest.lon]
  ];

  routeLine = L.polyline(latlngs, {
    color: 'rgba(74,158,255,0.5)',
    weight: 2,
    dashArray: '6, 4'
  }).addTo(map);

  // Origin marker
  if (originMarker) originMarker.remove();
  originMarker = L.circleMarker([origin.lat, origin.lon], {
    radius: 8, color: '#4a9eff', fillColor: '#4a9eff', fillOpacity: 0.8, weight: 2
  }).bindTooltip(`<b>${origin.icao}</b><br>${origin.name}`, { permanent: false })
    .addTo(map);

  // Dest marker
  if (destMarker) destMarker.remove();
  destMarker = L.circleMarker([dest.lat, dest.lon], {
    radius: 8, color: '#22d3a5', fillColor: '#22d3a5', fillOpacity: 0.8, weight: 2
  }).bindTooltip(`<b>${dest.icao}</b><br>${dest.name}`, { permanent: false })
    .addTo(map);

  map.fitBounds(routeLine.getBounds(), { padding: [40, 40] });
}

function updateTrail(lat, lon) {
  trailCoords.push([lat, lon]);
  if (trailCoords.length > 500) trailCoords.shift();

  if (trailLine) trailLine.remove();
  if (trailCoords.length > 1) {
    trailLine = L.polyline(trailCoords, {
      color: 'rgba(168,85,247,0.4)',
      weight: 2
    }).addTo(map);
  }
}

// ── Geo Helpers ────────────────────────────────────────────────────────
function toRad(deg) { return deg * Math.PI / 180; }
function toDeg(rad) { return rad * 180 / Math.PI; }

function greatCircleDistance(lat1, lon1, lat2, lon2) {
  const R = 3440.065; // nm
  const φ1 = toRad(lat1), φ2 = toRad(lat2);
  const Δφ = toRad(lat2 - lat1), Δλ = toRad(lon2 - lon1);
  const a = Math.sin(Δφ/2)**2 + Math.cos(φ1)*Math.cos(φ2)*Math.sin(Δλ/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function totalRouteDistance(waypoints, origin, dest) {
  const pts = [origin, ...waypoints, dest];
  let d = 0;
  for (let i = 0; i < pts.length - 1; i++) {
    d += greatCircleDistance(pts[i].lat, pts[i].lon, pts[i+1].lat, pts[i+1].lon);
  }
  return d;
}

function flownDistance(lat, lon, waypoints, origin) {
  // Simplified: great circle from origin to current position
  return greatCircleDistance(origin.lat, origin.lon, lat, lon);
}

// ── ETA Calculation ────────────────────────────────────────────────────
function calcETA(state) {
  if (!state.simbrief || !state.gs || state.gs < 30) return null;
  const { lat, lon, gs } = state;
  const dest = state.simbrief.destination;
  const distNm = greatCircleDistance(lat, lon, dest.lat, dest.lon);
  const etaSeconds = (distNm / gs) * 3600;
  return Date.now() + etaSeconds * 1000;
}

function calcProgress(state) {
  if (!state.simbrief || !state.lat) return 0;
  const { lat, lon, simbrief } = state;
  const total = totalRouteDistance(simbrief.waypoints || [], simbrief.origin, simbrief.destination);
  const flown = flownDistance(lat, lon, simbrief.waypoints || [], simbrief.origin);
  return Math.min(100, Math.max(0, (flown / total) * 100));
}

// ── Format Helpers ─────────────────────────────────────────────────────
function fmtISO(isoStr) {
  if (!isoStr) return '——:——';
  try {
    const d = new Date(isoStr);
    return d.toISOString().substr(11, 5) + 'Z';
  } catch { return '——:——'; }
}

function fmtTS(ms) {
  if (!ms) return '——:——';
  try {
    return new Date(ms).toISOString().substr(11, 5) + 'Z';
  } catch { return '——:——'; }
}

function fmtDuration(seconds) {
  if (!seconds || seconds < 0) return '——h ——m';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${h}h ${String(m).padStart(2,'0')}m`;
}

function fmtDelay(ms) {
  if (ms === null || ms === undefined) return '——';
  const sign = ms >= 0 ? '+' : '-';
  const abs = Math.abs(ms);
  const h = Math.floor(abs / 3_600_000);
  const m = Math.floor((abs % 3_600_000) / 60_000);
  if (h > 0) return `${sign}${h}h${String(m).padStart(2,'0')}m`;
  return `${sign}${m}m`;
}

// ── UI Update ──────────────────────────────────────────────────────────
function updateUI(s) {
  state = s;

  // Connection
  const dot = document.getElementById('conn-dot');
  const label = document.getElementById('conn-label');
  if (s.connected) {
    dot.className = 'connection-dot connected';
    label.textContent = `Connected — MSFS 2024`;
  } else {
    dot.className = 'connection-dot disconnected';
    label.textContent = 'Waiting for MSFS 2024...';
  }

  // SimBrief route info
  if (s.simbrief) {
    const sb = s.simbrief;
    document.getElementById('orig-icao').textContent = sb.origin.icao || '——';
    document.getElementById('orig-name').textContent = sb.origin.name || '';
    document.getElementById('orig-rwy').textContent = sb.origin.rwy ? `RWY ${sb.origin.rwy}` : '';
    document.getElementById('dest-icao').textContent = sb.destination.icao || '——';
    document.getElementById('dest-name').textContent = sb.destination.name || '';
    document.getElementById('dest-rwy').textContent = sb.destination.rwy ? `RWY ${sb.destination.rwy}` : '';
    document.getElementById('aircraft-type').textContent = sb.aircraft.type || '——';
    document.getElementById('flight-number').textContent = sb.flightNumber || '';
    document.getElementById('cruise-fl').textContent = `FL${Math.round((sb.cruiseAlt || 35000) / 100)}`;
    document.getElementById('pb-orig').textContent = sb.origin.icao || 'ORIG';
    document.getElementById('pb-dest').textContent = sb.destination.icao || 'DEST';

    // Draw route on first load
    if (sb.waypoints && sb.waypoints.length > 0 && !routeLine) {
      drawRoute(sb.waypoints, sb.origin, sb.destination);
    }
  }

  // Phase pill
  const pill = document.getElementById('phase-pill');
  pill.textContent = s.phase || 'PREFLIGHT';
  pill.className = 'phase-pill ' + (s.phase || 'PREFLIGHT');

  // Progress bar
  const pct = calcProgress(s);
  document.getElementById('progress-fill').style.width = pct + '%';
  document.getElementById('progress-plane').style.left = Math.max(2, Math.min(98, pct)) + '%';
  document.getElementById('pb-pct').textContent = Math.round(pct) + '%';

  // Live data
  document.getElementById('val-alt').textContent = s.alt ? Math.round(s.alt).toLocaleString() : '——';
  document.getElementById('val-ias').textContent = s.ias ? Math.round(s.ias) : '——';
  document.getElementById('val-gs').textContent  = s.gs  ? Math.round(s.gs)  : '——';
  document.getElementById('val-hdg').textContent = s.hdg ? Math.round(s.hdg) : '——';
  document.getElementById('val-vs').textContent  = s.vs  ? (s.vs > 0 ? '+' : '') + Math.round(s.vs) : '——';
  document.getElementById('val-fuel').textContent = s.fuel ? Math.round(s.fuel).toLocaleString() : '——';

  // Times
  const sb = s.simbrief;
  document.getElementById('t-std').textContent = fmtISO(sb?.times.std);
  document.getElementById('t-sta').textContent = fmtISO(sb?.times.sta);
  document.getElementById('t-atd').textContent = fmtTS(s.atd);

  const eta = calcETA(s);
  document.getElementById('t-eta').textContent = eta ? new Date(eta).toISOString().substr(11,5)+'Z' : '——:——';

  const remainMs = eta ? eta - Date.now() : null;
  document.getElementById('t-remaining').textContent = remainMs ? fmtDuration(remainMs / 1000) : '——h——m';

  const elapsed = s.atd ? Date.now() - s.atd : null;
  document.getElementById('t-elapsed').textContent = elapsed ? fmtDuration(elapsed / 1000) : '——:——';

  // Delay: ATD vs STD (both as timestamps)
  let delay = null;
  if (s.atd && sb?.times.std) {
    const stdMs = new Date(sb.times.std).getTime();
    delay = s.atd - stdMs; // positive = late, negative = early
  }
  document.getElementById('t-delay').textContent = delay !== null ? fmtDelay(delay) : 'On Time';
  document.getElementById('t-delay').style.color =
    delay === null ? 'var(--text-secondary)' :
    delay > 300000 ? 'var(--red)' :
    delay < -60000 ? 'var(--green)' : 'var(--text-secondary)';

  // Fuel gauge
  // SimConnect gives fuel in gallons. SimBrief block fuel is in lbs (if units=lbs) or kgs.
  // 1 gal JetA ≈ 6.7 lbs. Convert SimConnect gallons → lbs to compare.
  if (sb) {
    const rem = s.fuel || 0;
    const remLbs = rem * 6.7; // gallons → lbs
    const blockLbs = sb.fuel.block || 1;
    const fuelPct = Math.min(100, Math.max(0, (remLbs / blockLbs) * 100));

    const fillEl = document.getElementById('fuel-bar-fill');
    fillEl.style.width = fuelPct + '%';
    fillEl.className = 'fuel-bar-fill' + (fuelPct < 15 ? ' low' : fuelPct < 30 ? ' medium' : '');

    document.getElementById('fuel-rem-label').textContent = `${Math.round(rem).toLocaleString()} gal (${Math.round(remLbs).toLocaleString()} lbs)`;
    document.getElementById('fuel-trip-label').textContent = `Trip: ${sb.fuel.trip.toLocaleString()} ${sb.fuel.units}`;
    document.getElementById('fuel-reserve').textContent = `${sb.fuel.reserve.toLocaleString()} ${sb.fuel.units}`;

    // Estimated fuel at destination
    const etaSeconds = eta ? (eta - Date.now()) / 1000 : null;
    if (etaSeconds && sb.times.ete > 0) {
      const burnRate = sb.fuel.trip / sb.times.ete; // lbs/sec
      const remAtDest = Math.max(0, Math.round(remLbs - burnRate * etaSeconds));
      document.getElementById('fuel-dest').textContent = `~${remAtDest.toLocaleString()} lbs`;
    } else {
      document.getElementById('fuel-dest').textContent = '——';
    }
  }

  // Map coords
  if (s.lat && s.lon) {
    const latStr = (s.lat >= 0 ? s.lat.toFixed(4) + '°N' : Math.abs(s.lat).toFixed(4) + '°S');
    const lonStr = (s.lon >= 0 ? s.lon.toFixed(4) + '°E' : Math.abs(s.lon).toFixed(4) + '°W');
    document.getElementById('map-coords').textContent = `${latStr}  ${lonStr}`;
    document.getElementById('map-sim-time').textContent = new Date().toISOString().substr(11,5) + 'Z';

    updateAircraftMarker(s.lat, s.lon, s.hdg || 0);
    updateTrail(s.lat, s.lon);
  }
}

// ── Init ───────────────────────────────────────────────────────────────
async function init() {
  initMap();

  // Get initial state
  const initialState = await window.flightAPI.getState();
  if (initialState) updateUI(initialState);

  // Listen for real-time updates
  window.flightAPI.onStateUpdate((s) => updateUI(s));

  // Update time countdown every 30s
  setInterval(() => {
    if (state && state.atd) updateUI(state);
  }, 30_000);

  // SimBrief button
  document.getElementById('btn-simbrief').addEventListener('click', async () => {
    const btn = document.getElementById('btn-simbrief');
    btn.textContent = '⏳ Loading...';
    btn.disabled = true;
    const data = await window.flightAPI.loadSimBrief();
    btn.innerHTML = '<span class="btn-icon">📋</span> Load SimBrief Plan';
    btn.disabled = false;
    if (data) {
      routeLine = null; // force redraw
      updateUI({ ...state, simbrief: data });
    } else {
      btn.innerHTML = '<span class="btn-icon">❌</span> No Plan Found';
      setTimeout(() => { btn.innerHTML = '<span class="btn-icon">📋</span> Load SimBrief Plan'; }, 3000);
    }
  });

  // Window controls
  document.getElementById('btn-close').addEventListener('click', () => window.close());
  document.getElementById('btn-minimize').addEventListener('click', () => {
    // Minimize is handled by Electron
  });
}

document.addEventListener('DOMContentLoaded', init);
