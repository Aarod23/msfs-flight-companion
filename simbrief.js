const axios = require('axios');

const PILOT_ID = '1246391';
const API_URL = `https://www.simbrief.com/api/xml.fetcher.php?userid=${PILOT_ID}&json=v2`;

// Parse "HH:MM:SS" duration string → seconds
function parseDuration(str) {
  if (!str) return 0;
  const parts = String(str).split(':').map(Number);
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 3600 + parts[1] * 60;
  return parseInt(str) || 0;
}

async function fetchOFP() {
  try {
    console.log('[SimBrief] Fetching OFP for pilot ID:', PILOT_ID);
    const res = await axios.get(API_URL, { timeout: 15000 });
    const d = res.data;

    if (!d || !d.origin) {
      console.warn('[SimBrief] No active flight plan found');
      return null;
    }

    // Parse waypoints from navlog
    const navlog = d.navlog?.fix || [];
    const waypoints = Array.isArray(navlog) ? navlog.map(wp => ({
      ident: wp.ident,
      lat: parseFloat(wp.pos_lat),
      lon: parseFloat(wp.pos_long),
      alt: parseInt(wp.altitude_feet || 0),
      type: wp.type
    })) : [];

    const plan = {
      origin: {
        icao: d.origin?.icao_code,
        name: d.origin?.name,
        lat: parseFloat(d.origin?.pos_lat || 0),
        lon: parseFloat(d.origin?.pos_long || 0),
        rwy: d.origin?.plan_rwy
      },
      destination: {
        icao: d.destination?.icao_code,
        name: d.destination?.name,
        lat: parseFloat(d.destination?.pos_lat || 0),
        lon: parseFloat(d.destination?.pos_long || 0),
        rwy: d.destination?.plan_rwy
      },
      alternate: {
        icao: d.alternate?.icao_code,
        name: d.alternate?.name
      },
      aircraft: {
        type: d.aircraft?.icaocode,
        reg: d.aircraft?.reg,
        name: d.aircraft?.name
      },
      times: {
        // Scheduled block off (OUT) — ISO 8601 string e.g. "2026-07-07T16:55:00Z"
        std:       d.times?.sched_out  || null,
        // Scheduled block on (IN)
        sta:       d.times?.sched_in   || null,
        // Estimated OUT/IN
        estOut:    d.times?.est_out    || null,
        estIn:     d.times?.est_in     || null,
        // Scheduled wheels up (OFF) / wheels down (ON)
        schedOff:  d.times?.sched_off  || null,
        schedOn:   d.times?.sched_on   || null,
        // Durations as seconds
        ete:       parseDuration(d.times?.est_time_enroute),   // estimated enroute
        eteScheduled: parseDuration(d.times?.sched_time_enroute),
        blockTime: parseDuration(d.times?.sched_block),        // scheduled block
        estBlock:  parseDuration(d.times?.est_block),          // estimated block
        taxiOut:   parseDuration(d.times?.taxi_out),
        taxiIn:    parseDuration(d.times?.taxi_in),
        endurance: parseDuration(d.times?.endurance)
      },
      fuel: {
        units: d.params?.units || 'LBS',
        block:    parseInt(d.fuel?.plan_ramp || 0),
        trip:     parseInt(d.fuel?.enroute_burn || 0),
        taxi:     parseInt(d.fuel?.taxi || 0),
        reserve:  parseInt(d.fuel?.reserve || 0),
        alternate: parseInt(d.fuel?.alternate_burn || 0),
        contingency: parseInt(d.fuel?.contingency || 0),
        landing:  parseInt(d.fuel?.plan_landing || 0),
        maxTanks: parseInt(d.fuel?.max_tanks || 0)
      },
      cruiseAlt:   parseInt(d.general?.initial_altitude || 35000),
      cruiseSpeed: d.general?.cruise_tas,
      route:       d.general?.route || '',
      waypoints,
      costIndex:   d.general?.costindex,
      flightNumber: d.general?.flight_number || '',
      ofpLayout:   d.params?.ofp_layout,
      fetchedAt:   Date.now()
    };

    console.log(`[SimBrief] Loaded: ${plan.origin.icao} → ${plan.destination.icao} (${plan.aircraft.type})`);
    console.log(`[SimBrief] STD: ${plan.times.std} | STA: ${plan.times.sta}`);
    console.log(`[SimBrief] Block time: ${Math.floor(plan.times.blockTime/3600)}h ${Math.floor((plan.times.blockTime%3600)/60)}m`);
    return plan;

  } catch (err) {
    console.error('[SimBrief] Fetch failed:', err.message);
    return null;
  }
}

module.exports = { fetchOFP };
