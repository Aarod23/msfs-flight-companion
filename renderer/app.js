/* =====================================================================
   MSFS Flight Companion — Renderer
   MapLibre GL JS + AI Traffic + Floating UI panels
===================================================================== */

'use strict';

// ── State ──────────────────────────────────────────────────────────────
let state   = null;
let traffic = [];
let map     = null;
let userMarker = null;
let trailCoords = [];
let satelliteMode = true;
let followAircraft = true;

// ── Aircraft Classification ────────────────────────────────────────────
const HEAVY_TYPES    = ['B747','B74S','B74F','B748','B77L','B77W','B772','B773','B77F','B788','B789','B78X','A380','A388','A350','A35K','A359','A332','A333','A338','A339','IL96','A124','MD11'];
const REGIONAL_TYPES = ['E170','E175','E190','E195','CRJ','CRJ1','CRJ2','CRJ7','CRJ9','CRJX','AT43','AT72','AT75','AT76','DH8A','DH8B','DH8C','DH8D','SF34','JS41','E120','BERE','F70','F100','RJ85','BA46'];
const GA_TYPES       = ['C172','C152','C182','C206','C208','PA28','PA34','PA44','BE58','BE9L','DA40','DA42','SR22','SR20','M20J','DV20','TBM9','PC12','C400','C340','P28A','P28B','C525'];
const HELI_TYPES     = ['H60','H135','H145','EC35','EC45','B06','B407','B427','B429','R22','R44','R66','EC20','AS50','AS35','S76','AW13','AW16','H120','H125','H130','UH60','MI8','S300'];
const MILITARY_TYPES = ['F16','F18','F22','F35','F14','F15','A10','B52','B2','B1','F117','T38','T45','SU27','SU25','MIG','EF20','EUFI','GROB','C130','KC13','C5','C17','P3','E3'];

function classifyAircraft(model = '') {
  const m = model.toUpperCase();
  if (HEAVY_TYPES.some(t => m.includes(t)))    return 'heavy';
  if (REGIONAL_TYPES.some(t => m.includes(t))) return 'regional';
  if (GA_TYPES.some(t => m.includes(t)))       return 'ga';
  if (HELI_TYPES.some(t => m.includes(t)))     return 'helicopter';
  if (MILITARY_TYPES.some(t => m.includes(t))) return 'military';
  return 'narrow'; // default: narrow-body airliner
}

// ── SVG Icon Generators ────────────────────────────────────────────────
function svgNarrow(size=32, color='#ffffff') {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 32 32">
    <defs><filter id="g"><feDropShadow dx="0" dy="0" stdDeviation="1.5" flood-color="${color}" flood-opacity="0.5"/></filter></defs>
    <g filter="url(#g)">
      <ellipse cx="16" cy="16" rx="2" ry="10" fill="${color}" opacity="0.95"/>
      <path d="M16 5.5 C14.5 7.5 14 9 16 9.5 C18 9 17.5 7.5 16 5.5Z" fill="${color}"/>
      <path d="M14.5 14 L3 19.5 L3.5 21.5 L15 17Z" fill="${color}" opacity="0.9"/>
      <path d="M17.5 14 L29 19.5 L28.5 21.5 L17 17Z" fill="${color}" opacity="0.9"/>
      <ellipse cx="16" cy="15.5" rx="2.5" ry="1.8" fill="${color}"/>
      <rect x="5.5" y="19.5" width="4.5" height="2" rx="1" fill="${color}" opacity="0.78"/>
      <rect x="22" y="19.5" width="4.5" height="2" rx="1" fill="${color}" opacity="0.78"/>
      <path d="M15 25 L11 28 L11.5 29 L15.5 26.5Z" fill="${color}" opacity="0.82"/>
      <path d="M17 25 L21 28 L20.5 29 L16.5 26.5Z" fill="${color}" opacity="0.82"/>
      <ellipse cx="16" cy="27" rx="1.2" ry="2" fill="${color}" opacity="0.88"/>
    </g>
  </svg>`;
}

function svgHeavy(size=36, color='#ffffff') {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 36 36">
    <defs><filter id="g"><feDropShadow dx="0" dy="0" stdDeviation="2" flood-color="${color}" flood-opacity="0.4"/></filter></defs>
    <g filter="url(#g)">
      <ellipse cx="18" cy="18" rx="2.8" ry="13" fill="${color}" opacity="0.97"/>
      <path d="M18 4 C16 7 15.2 9.5 18 10.5 C20.8 9.5 20 7 18 4Z" fill="${color}"/>
      <path d="M15.5 15 L1 22 L1.5 25 L16 19Z" fill="${color}" opacity="0.92"/>
      <path d="M20.5 15 L35 22 L34.5 25 L20 19Z" fill="${color}" opacity="0.92"/>
      <ellipse cx="18" cy="16.5" rx="3.5" ry="2.5" fill="${color}"/>
      <rect x="4" y="21" width="5" height="2.2" rx="1.1" fill="${color}" opacity="0.8"/>
      <rect x="8.5" y="21" width="5" height="2.2" rx="1.1" fill="${color}" opacity="0.75"/>
      <rect x="22.5" y="21" width="5" height="2.2" rx="1.1" fill="${color}" opacity="0.8"/>
      <rect x="27" y="21" width="5" height="2.2" rx="1.1" fill="${color}" opacity="0.75"/>
      <path d="M16.5 28 L9 33 L9.5 34.5 L17.2 30Z" fill="${color}" opacity="0.88"/>
      <path d="M19.5 28 L27 33 L26.5 34.5 L18.8 30Z" fill="${color}" opacity="0.88"/>
      <ellipse cx="18" cy="30.5" rx="1.8" ry="3" fill="${color}" opacity="0.9"/>
    </g>
  </svg>`;
}

function svgRegional(size=26, color='#ffffff') {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 26 26">
    <defs><filter id="g"><feDropShadow dx="0" dy="0" stdDeviation="1.2" flood-color="${color}" flood-opacity="0.4"/></filter></defs>
    <g filter="url(#g)">
      <ellipse cx="13" cy="13" rx="1.8" ry="8.5" fill="${color}" opacity="0.95"/>
      <path d="M13 4 C11.5 6 11 7.5 13 8 C15 7.5 14.5 6 13 4Z" fill="${color}"/>
      <path d="M11.5 11.5 L2 16 L2.5 17.8 L12 14Z" fill="${color}" opacity="0.88"/>
      <path d="M14.5 11.5 L24 16 L23.5 17.8 L14 14Z" fill="${color}" opacity="0.88"/>
      <ellipse cx="13" cy="12.5" rx="2" ry="1.6" fill="${color}"/>
      <path d="M12 19.5 L8 22.5 L8.4 23.5 L12.5 21Z" fill="${color}" opacity="0.8"/>
      <path d="M14 19.5 L18 22.5 L17.6 23.5 L13.5 21Z" fill="${color}" opacity="0.8"/>
      <ellipse cx="13" cy="21.5" rx="1" ry="1.8" fill="${color}" opacity="0.85"/>
    </g>
  </svg>`;
}

function svgGA(size=22, color='#ffffff') {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 22 22">
    <defs><filter id="g"><feDropShadow dx="0" dy="0" stdDeviation="1" flood-color="${color}" flood-opacity="0.4"/></filter></defs>
    <g filter="url(#g)">
      <ellipse cx="11" cy="11" rx="1.5" ry="7" fill="${color}" opacity="0.92"/>
      <path d="M11 3.5 C9.8 5 9.4 6.2 11 6.8 C12.6 6.2 12.2 5 11 3.5Z" fill="${color}"/>
      <path d="M9.5 9.5 L1.5 13 L2 14.5 L10 11.5Z" fill="${color}" opacity="0.85"/>
      <path d="M12.5 9.5 L20.5 13 L20 14.5 L12 11.5Z" fill="${color}" opacity="0.85"/>
      <ellipse cx="11" cy="10" rx="1.8" ry="1.3" fill="${color}"/>
      <circle cx="11" cy="4.8" r="2.5" fill="none" stroke="${color}" stroke-width="0.8" opacity="0.5"/>
      <path d="M10.2 16 L7.5 18.5 L7.8 19.3 L10.6 17.2Z" fill="${color}" opacity="0.75"/>
      <path d="M11.8 16 L14.5 18.5 L14.2 19.3 L11.4 17.2Z" fill="${color}" opacity="0.75"/>
    </g>
  </svg>`;
}

function svgHelicopter(size=26, color='#ffffff') {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 26 26">
    <defs><filter id="g"><feDropShadow dx="0" dy="0" stdDeviation="1.2" flood-color="${color}" flood-opacity="0.4"/></filter></defs>
    <g filter="url(#g)">
      <!-- Main rotor (horizontal blades) -->
      <ellipse cx="13" cy="8" rx="10" ry="1.2" fill="${color}" opacity="0.85"/>
      <ellipse cx="13" cy="8" rx="1.2" ry="8" fill="${color}" opacity="0.7"/>
      <circle cx="13" cy="8" r="1.8" fill="${color}"/>
      <!-- Fuselage body -->
      <ellipse cx="13" cy="15" rx="3" ry="5" fill="${color}" opacity="0.95"/>
      <!-- Cockpit bubble -->
      <ellipse cx="13" cy="12" rx="3.5" ry="2.5" fill="${color}"/>
      <!-- Tail boom -->
      <rect x="11.8" y="19" width="1.4" height="5" rx="0.7" fill="${color}" opacity="0.8"/>
      <!-- Tail rotor -->
      <ellipse cx="13" cy="24" rx="3.5" ry="0.8" fill="${color}" opacity="0.7"/>
      <!-- Skids -->
      <line x1="9" y1="20" x2="17" y2="20" stroke="${color}" stroke-width="1.2" opacity="0.6"/>
    </g>
  </svg>`;
}

function svgMilitary(size=28, color='#ffffff') {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 28 28">
    <defs><filter id="g"><feDropShadow dx="0" dy="0" stdDeviation="1.5" flood-color="${color}" flood-opacity="0.5"/></filter></defs>
    <g filter="url(#g)">
      <!-- Delta wing fuselage -->
      <path d="M14 2 L18 20 L14 18 L10 20 Z" fill="${color}" opacity="0.95"/>
      <!-- Main delta wings -->
      <path d="M14 8 L3 22 L10 20 Z" fill="${color}" opacity="0.88"/>
      <path d="M14 8 L25 22 L18 20 Z" fill="${color}" opacity="0.88"/>
      <!-- Canards -->
      <path d="M14 10 L8 14 L10 14.5 Z" fill="${color}" opacity="0.7"/>
      <path d="M14 10 L20 14 L18 14.5 Z" fill="${color}" opacity="0.7"/>
      <!-- Tail fins -->
      <path d="M13 18 L10 24 L14 22 Z" fill="${color}" opacity="0.75"/>
      <path d="M15 18 L18 24 L14 22 Z" fill="${color}" opacity="0.75"/>
      <!-- Nose -->
      <line x1="14" y1="2" x2="14" y2="5" stroke="${color}" stroke-width="1.2"/>
    </g>
  </svg>`;
}

function svgUserAircraft(heading) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="44" height="44" viewBox="0 0 44 44">
    <defs>
      <filter id="ac-shadow">
        <feDropShadow dx="0" dy="0" stdDeviation="2.5" flood-color="rgba(255,255,255,0.45)"/>
      </filter>
    </defs>
    <g transform="rotate(${heading}, 22, 22)" filter="url(#ac-shadow)">
      <ellipse cx="22" cy="22" rx="2.6" ry="14" fill="white" opacity="0.97"/>
      <path d="M22 7 C20.4 9.5 19.6 11.5 22 12.5 C24.4 11.5 23.6 9.5 22 7Z" fill="white"/>
      <path d="M20.2 19.5 L3.5 26.5 L4.2 29 L21 23.5Z" fill="white" opacity="0.94"/>
      <path d="M23.8 19.5 L40.5 26.5 L39.8 29 L23 23.5Z" fill="white" opacity="0.94"/>
      <ellipse cx="22" cy="21.5" rx="3.4" ry="2.4" fill="white"/>
      <rect x="7" y="25" width="6" height="2.5" rx="1.25" fill="white" opacity="0.82"/>
      <rect x="31" y="25" width="6" height="2.5" rx="1.25" fill="white" opacity="0.82"/>
      <path d="M20.5 33.5 L12.5 38 L13.2 39.5 L21.3 35.5Z" fill="white" opacity="0.88"/>
      <path d="M23.5 33.5 L31.5 38 L30.8 39.5 L22.7 35.5Z" fill="white" opacity="0.88"/>
      <ellipse cx="22" cy="36" rx="1.5" ry="2.8" fill="white" opacity="0.92"/>
      <ellipse cx="22" cy="10.5" rx="1.1" ry="1.5" fill="rgba(10,10,10,0.5)"/>
      <ellipse cx="21.6" cy="22" rx="0.7" ry="9.5" fill="rgba(255,255,255,0.18)"/>
    </g>
  </svg>`;
}

// Create a data URL from an SVG string
function svgToDataURL(svgStr) {
  return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svgStr);
}

// Load an SVG as a MapLibre-compatible Image
function loadMapImage(map, id, svgStr, size) {
  return new Promise((resolve, reject) => {
    const img = new Image(size, size);
    img.onload = () => { map.addImage(id, img, { sdf: false }); resolve(); };
    img.onerror = reject;
    img.src = svgToDataURL(svgStr);
  });
}

// ── Map Initialization ─────────────────────────────────────────────────
async function initMap() {
  map = new maplibregl.Map({
    container: 'map',
    style: buildSatelliteStyle(),
    center: [-98, 38],
    zoom: 3.5,
    maxZoom: 18,
    minZoom: 1,
    attributionControl: false,
    logoPosition: 'bottom-right'
  });

  map.addControl(new maplibregl.NavigationControl({ showCompass: true }), 'bottom-right');

  map.on('load', async () => {
    await registerIcons();
    addMapLayers();
    console.log('[Map] Ready');
  });

  // Click on AI traffic symbol → show popup
  map.on('click', 'ai-traffic-layer', (e) => {
    if (!e.features.length) return;
    showTrafficPopup(e.features[0].properties, e.lngLat);
  });
  map.on('mouseenter', 'ai-traffic-layer', () => { map.getCanvas().style.cursor = 'pointer'; });
  map.on('mouseleave', 'ai-traffic-layer', () => { map.getCanvas().style.cursor = ''; });
}

function buildSatelliteStyle() {
  return {
    version: 8,
    sources: {
      'esri-sat': {
        type: 'raster',
        tiles: ['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
        tileSize: 256,
        attribution: '© Esri, DigitalGlobe'
      },
      'osm-labels': {
        type: 'raster',
        tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
        tileSize: 256
      }
    },
    layers: [
      { id: 'sat-base', type: 'raster', source: 'esri-sat', paint: { 'raster-saturation': -0.2, 'raster-brightness-min': 0.05 } }
    ]
  };
}

function buildDarkStyle() {
  return {
    version: 8,
    sources: {
      'carto-dark': {
        type: 'raster',
        tiles: ['https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'],
        tileSize: 512,
        attribution: '© CARTO'
      }
    },
    layers: [
      { id: 'dark-base', type: 'raster', source: 'carto-dark' }
    ]
  };
}

async function registerIcons() {
  const icons = [
    ['ac-narrow',     svgNarrow(32, '#ffffff'), 32],
    ['ac-heavy',      svgHeavy(36, '#ffffff'), 36],
    ['ac-regional',   svgRegional(26, '#ffffff'), 26],
    ['ac-ga',         svgGA(22, '#c8f9e8'), 22],
    ['ac-helicopter', svgHelicopter(26, '#fde68a'), 26],
    ['ac-military',   svgMilitary(28, '#fca5a5'), 28],
  ];
  await Promise.all(icons.map(([id, svg, size]) => loadMapImage(map, id, svg, size)));
}

function addMapLayers() {
  // ── Route line (SimBrief) ──
  map.addSource('route', {
    type: 'geojson',
    data: { type: 'Feature', geometry: { type: 'LineString', coordinates: [] } }
  });
  map.addLayer({
    id: 'route-line',
    type: 'line',
    source: 'route',
    layout: { 'line-join': 'round', 'line-cap': 'round' },
    paint: {
      'line-color': '#ffffff',
      'line-width': 1.5,
      'line-opacity': 0.35,
      'line-dasharray': [4, 3]
    }
  });

  // ── Flight trail ──
  map.addSource('trail', {
    type: 'geojson',
    data: { type: 'Feature', geometry: { type: 'LineString', coordinates: [] } }
  });
  map.addLayer({
    id: 'trail-line',
    type: 'line',
    source: 'trail',
    layout: { 'line-join': 'round', 'line-cap': 'round' },
    paint: {
      'line-color': '#34d399',
      'line-width': 2,
      'line-opacity': 0.7
    }
  });

  // ── Waypoints ──
  map.addSource('waypoints', {
    type: 'geojson',
    data: { type: 'FeatureCollection', features: [] }
  });
  map.addLayer({
    id: 'waypoints-layer',
    type: 'circle',
    source: 'waypoints',
    paint: {
      'circle-radius': 3,
      'circle-color': 'rgba(255,255,255,0.15)',
      'circle-stroke-color': 'rgba(255,255,255,0.4)',
      'circle-stroke-width': 1
    }
  });

  // ── Airport markers ──
  map.addSource('airports', {
    type: 'geojson',
    data: { type: 'FeatureCollection', features: [] }
  });
  map.addLayer({
    id: 'airports-layer',
    type: 'circle',
    source: 'airports',
    paint: {
      'circle-radius': 6,
      'circle-color': ['match', ['get', 'type'],
        'origin', 'rgba(52,211,153,0.25)',
        'destination', 'rgba(248,113,113,0.25)',
        'rgba(255,255,255,0.15)'
      ],
      'circle-stroke-color': ['match', ['get', 'type'],
        'origin', '#34d399',
        'destination', '#f87171',
        '#ffffff'
      ],
      'circle-stroke-width': 2
    }
  });

  // ── AI Traffic ──
  map.addSource('traffic', {
    type: 'geojson',
    data: { type: 'FeatureCollection', features: [] }
  });
  map.addLayer({
    id: 'ai-traffic-layer',
    type: 'symbol',
    source: 'traffic',
    layout: {
      'icon-image': ['match', ['get', 'category'],
        'heavy',      'ac-heavy',
        'regional',   'ac-regional',
        'ga',         'ac-ga',
        'helicopter', 'ac-helicopter',
        'military',   'ac-military',
        'ac-narrow'  // default
      ],
      'icon-rotate':               ['get', 'heading'],
      'icon-rotation-alignment':   'map',
      'icon-allow-overlap':        true,
      'icon-ignore-placement':     true,
      'icon-size': [
        'interpolate', ['linear'], ['zoom'],
        2, 0.25,
        6, 0.55,
        10, 0.9,
        14, 1.3
      ]
    },
    paint: {
      'icon-opacity': ['interpolate', ['linear'], ['get', 'alt'],
        0,    0.6,
        1000, 0.8,
        5000, 0.95
      ]
    }
  });
}

// ── User aircraft marker ───────────────────────────────────────────────
function updateUserMarker(lat, lon, heading) {
  const el = document.createElement('div');
  el.className = 'user-aircraft-marker';
  el.style.cssText = 'width:44px;height:44px;pointer-events:none;';
  el.innerHTML = svgUserAircraft(heading);

  if (userMarker) {
    userMarker.setLngLat([lon, lat]);
    userMarker.getElement().innerHTML = svgUserAircraft(heading);
  } else {
    userMarker = new maplibregl.Marker({ element: el, anchor: 'center' })
      .setLngLat([lon, lat])
      .addTo(map);
  }
}

// ── Trail ──────────────────────────────────────────────────────────────
function updateTrail(lat, lon) {
  trailCoords.push([lon, lat]);
  if (trailCoords.length > 2000) trailCoords.shift();
  const src = map.getSource('trail');
  if (src) src.setData({ type: 'Feature', geometry: { type: 'LineString', coordinates: trailCoords } });
}

// ── Route from SimBrief ────────────────────────────────────────────────
function drawRoute(simbrief) {
  const wps = simbrief.waypoints || [];
  const orig = simbrief.origin;
  const dest = simbrief.destination;

  const coords = [];
  if (orig?.lat && orig?.lon) coords.push([orig.lon, orig.lat]);
  wps.filter(w => w.lat && w.lon).forEach(w => coords.push([w.lon, w.lat]));
  if (dest?.lat && dest?.lon) coords.push([dest.lon, dest.lat]);

  const routeSrc = map.getSource('route');
  if (routeSrc) routeSrc.setData({ type: 'Feature', geometry: { type: 'LineString', coordinates: coords } });

  // Waypoints
  const wpFeatures = wps.slice(0, 100).filter(w => w.lat && w.lon).map(w => ({
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [w.lon, w.lat] },
    properties: { ident: w.ident }
  }));
  const wpSrc = map.getSource('waypoints');
  if (wpSrc) wpSrc.setData({ type: 'FeatureCollection', features: wpFeatures });

  // Airport markers
  const apFeatures = [];
  if (orig?.lat) apFeatures.push({ type: 'Feature', geometry: { type: 'Point', coordinates: [orig.lon, orig.lat] }, properties: { type: 'origin', icao: orig.icao } });
  if (dest?.lat) apFeatures.push({ type: 'Feature', geometry: { type: 'Point', coordinates: [dest.lon, dest.lat] }, properties: { type: 'destination', icao: dest.icao } });
  const apSrc = map.getSource('airports');
  if (apSrc) apSrc.setData({ type: 'FeatureCollection', features: apFeatures });

  // Fit map to route
  if (coords.length >= 2) {
    const bounds = coords.reduce((b, c) => b.extend(c), new maplibregl.LngLatBounds(coords[0], coords[0]));
    map.fitBounds(bounds, { padding: 120, duration: 1200 });
  }
}

// ── AI Traffic Rendering ───────────────────────────────────────────────
function updateTrafficLayer(trafficList) {
  const features = trafficList.map(t => ({
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [t.lon, t.lat] },
    properties: {
      objectId: t.objectId,
      callsign: t.callsign || `AI-${t.objectId}`,
      model:    t.model    || 'UNKN',
      airline:  t.airline  || '',
      category: classifyAircraft(t.model || ''),
      heading:  t.hdg      || 0,
      alt:      Math.round(t.alt || 0),
      gs:       Math.round(t.gs  || 0),
      onGround: t.onGround ? 1 : 0
    }
  }));

  const src = map.getSource('traffic');
  if (src) src.setData({ type: 'FeatureCollection', features });
}

// ── Traffic Popup ──────────────────────────────────────────────────────
function showTrafficPopup(props, lngLat) {
  const popup = document.getElementById('traffic-popup');
  const tp = popup.getBoundingClientRect();
  const pt = map.project(lngLat);

  document.getElementById('tp-callsign').textContent = props.callsign || `AI-${props.objectId}`;
  document.getElementById('tp-model').textContent    = props.model    || '——';
  document.getElementById('tp-alt').textContent      = props.alt ? props.alt.toLocaleString() + ' ft' : '——';
  document.getElementById('tp-gs').textContent       = props.gs  ? props.gs  + ' kts' : '——';
  document.getElementById('tp-hdg').textContent      = props.heading !== undefined ? Math.round(props.heading) + '°' : '——';

  popup.style.left = (pt.x + 16) + 'px';
  popup.style.top  = (pt.y - 40) + 'px';
  popup.style.display = 'block';
}

document.getElementById('tp-close').addEventListener('click', () => {
  document.getElementById('traffic-popup').style.display = 'none';
});

// ── Format Helpers ─────────────────────────────────────────────────────
function fmtISO(iso) {
  if (!iso) return '——:——';
  try { return new Date(iso).toISOString().substr(11, 5) + 'Z'; } catch { return '——:——'; }
}
function fmtTS(ms) {
  if (!ms) return '——:——';
  try { return new Date(ms).toISOString().substr(11, 5) + 'Z'; } catch { return '——:——'; }
}
function fmtDur(sec) {
  if (!sec || sec < 0) return '——h ——m';
  return `${Math.floor(sec/3600)}h ${String(Math.floor((sec%3600)/60)).padStart(2,'0')}m`;
}
function fmtDelay(ms) {
  if (ms === null || ms === undefined) return '';
  const sign = ms >= 0 ? '+' : '-';
  const abs  = Math.abs(ms);
  const h    = Math.floor(abs / 3_600_000);
  const m    = Math.floor((abs % 3_600_000) / 60_000);
  return h > 0 ? `${sign}${h}h${String(m).padStart(2,'0')}m` : `${sign}${m}m`;
}

// ── ETA Calculation ────────────────────────────────────────────────────
function calcETA(s) {
  if (!s?.simbrief?.times) return null;
  const { std, sta, ete } = s.simbrief.times;
  // Use estimated in time from SimBrief as the best ETA
  if (s.simbrief.times.estIn) return new Date(s.simbrief.times.estIn).getTime();
  if (sta) return new Date(sta).getTime();
  return null;
}

function calcProgress(s) {
  if (!s?.simbrief?.times) return 0;
  const { std, sta } = s.simbrief.times;
  if (!std || !sta) return 0;
  const total = new Date(sta) - new Date(std);
  const elapsed = Date.now() - (s.atd || new Date(std).getTime());
  return Math.min(100, Math.max(0, (elapsed / total) * 100));
}

// ── UI Update ──────────────────────────────────────────────────────────
let routeDrawn = false;

function updateUI(s) {
  state = s;

  // Connection
  const dot  = document.getElementById('conn-dot');
  const lbl  = document.getElementById('conn-label');
  if (s.connected) {
    dot.className = 'conn-dot connected';
    lbl.textContent = `MSFS Connected`;
  } else {
    dot.className = 'conn-dot disconnected';
    lbl.textContent = 'Waiting for MSFS…';
  }

  // Route badge + header
  if (s.simbrief) {
    const sb = s.simbrief;
    document.getElementById('rb-orig').textContent = sb.origin.icao || '——';
    document.getElementById('rb-dest').textContent = sb.destination.icao || '——';
    document.getElementById('rb-ac').textContent   = sb.aircraft.type || '——';
    const fn = document.getElementById('rb-fn');
    fn.textContent = sb.flightNumber || '';
    const fl = document.getElementById('rb-fl');
    fl.textContent = `FL${Math.round((sb.cruiseAlt || 35000) / 100)}`;

    document.getElementById('fi-orig').textContent = sb.origin.icao || '——';
    document.getElementById('fi-dest').textContent = sb.destination.icao || '——';

    // Draw route on map (once)
    if (!routeDrawn && map && map.isStyleLoaded()) {
      drawRoute(sb);
      routeDrawn = true;
    }
  }

  // Phase
  const phase = s.phase || 'PREFLIGHT';
  const pill  = document.getElementById('fi-phase');
  pill.textContent = phase;
  pill.className   = `phase-pill ${phase}`;

  // Progress bar
  const pct = calcProgress(s);
  document.getElementById('fi-progress-fill').style.width = pct + '%';
  document.getElementById('fi-progress-plane').style.left = Math.max(2, Math.min(97, pct)) + '%';

  // Live data
  document.getElementById('ld-alt').textContent  = s.alt  ? Math.round(s.alt).toLocaleString() : '——';
  document.getElementById('ld-ias').textContent  = s.ias  ? Math.round(s.ias) : '——';
  document.getElementById('ld-gs').textContent   = s.gs   ? Math.round(s.gs)  : '——';
  document.getElementById('ld-hdg').textContent  = s.hdg  ? Math.round(s.hdg) : '——';
  const vsEl = document.getElementById('ld-vs');
  vsEl.textContent = s.vs ? (s.vs > 0 ? '+' : '') + Math.round(s.vs) : '——';
  vsEl.style.color = s.vs > 100 ? 'var(--green)' : s.vs < -100 ? 'var(--red)' : '';
  document.getElementById('ld-fuel').textContent = s.fuel ? Math.round(s.fuel).toLocaleString() : '——';

  // Times
  const sb = s.simbrief;
  document.getElementById('fi-std').textContent = fmtISO(sb?.times.std);
  document.getElementById('fi-sta').textContent = fmtISO(sb?.times.sta);
  document.getElementById('fi-atd').textContent = fmtTS(s.atd);

  const eta = calcETA(s);
  document.getElementById('fi-eta').textContent     = eta ? fmtTS(eta) : '——:——';
  document.getElementById('fi-eta-sub').textContent = eta ? `ETA ${fmtTS(eta)}` : 'ETA ——:——Z';

  const remainMs = eta ? eta - Date.now() : null;
  document.getElementById('fi-rem').textContent = remainMs ? fmtDur(remainMs / 1000) : '——h ——m';

  // Delay chip
  const delayChip = document.getElementById('delay-chip');
  if (s.atd && sb?.times.std) {
    const delay = s.atd - new Date(sb.times.std).getTime();
    const delayEl = document.getElementById('delay-val');
    delayEl.textContent = fmtDelay(delay);
    delayChip.style.display = 'block';
    delayChip.className     = delay > 0 ? 'delay-chip' : 'delay-chip early';
  } else {
    delayChip.style.display = 'none';
  }

  // Map: user aircraft
  if (s.lat && s.lon && map) {
    updateUserMarker(s.lat, s.lon, s.hdg || 0);
    updateTrail(s.lat, s.lon);
    if (followAircraft) {
      map.easeTo({ center: [s.lon, s.lat], duration: 1000, essential: false });
    }
  }
}

// ── Satellite Toggle ───────────────────────────────────────────────────
document.getElementById('btn-satellite').addEventListener('click', () => {
  satelliteMode = !satelliteMode;
  const style = satelliteMode ? buildSatelliteStyle() : buildDarkStyle();
  map.setStyle(style);
  map.once('style.load', async () => {
    await registerIcons();
    addMapLayers();
    // Redraw route if needed
    if (state?.simbrief) drawRoute(state.simbrief);
    // Redraw trail
    const src = map.getSource('trail');
    if (src) src.setData({ type: 'Feature', geometry: { type: 'LineString', coordinates: trailCoords } });
    // Redraw traffic
    if (traffic.length) updateTrafficLayer(traffic);
    routeDrawn = state?.simbrief ? true : false;
  });
  document.getElementById('btn-satellite').textContent = satelliteMode ? '🛰 Satellite' : '🗺 Dark Map';
});

// ── Title bar controls ─────────────────────────────────────────────────
document.getElementById('btn-close').addEventListener('click', () => {
  // Electron hides window (tray behavior is in main process)
  window.close();
});
document.getElementById('btn-minimize').addEventListener('click', () => {
  require('electron').ipcRenderer?.send('minimize');
});

// ── SimBrief button ────────────────────────────────────────────────────
document.getElementById('btn-simbrief').addEventListener('click', async () => {
  const btn = document.getElementById('btn-simbrief');
  btn.textContent = '⏳ Loading…';
  btn.disabled = true;
  try {
    const data = await window.flightAPI.loadSimBrief();
    if (data) {
      routeDrawn = false; // force redraw
      btn.textContent = `✅ ${data.origin.icao}→${data.destination.icao}`;
    } else {
      btn.textContent = '❌ No Plan';
    }
  } catch (e) {
    btn.textContent = '❌ Error';
  }
  setTimeout(() => { btn.textContent = '📋 SimBrief'; btn.disabled = false; }, 3000);
});

// ── Entry Point ────────────────────────────────────────────────────────
async function init() {
  await initMap();

  // Get initial state
  const s = await window.flightAPI.getState();
  if (s) updateUI(s);

  // Get initial traffic
  const t = await window.flightAPI.getTraffic();
  if (t?.length) {
    traffic = t;
    if (map.isStyleLoaded()) updateTrafficLayer(traffic);
  }

  // Real-time state updates
  window.flightAPI.onStateUpdate((s) => updateUI(s));

  // Real-time traffic updates
  window.flightAPI.onTrafficUpdate((t) => {
    traffic = t;
    if (map && map.isStyleLoaded()) updateTrafficLayer(traffic);
  });

  // Refresh ETA/remaining every 30s
  setInterval(() => { if (state) updateUI(state); }, 30_000);
}

init().catch(console.error);
