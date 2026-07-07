const axios = require('axios');

const PILOT_ID = '1246391';
const API_URL = `https://www.simbrief.com/api/xml.fetcher.php?userid=${PILOT_ID}&json=v2`;

function parseTime(utcSeconds) {
  if (!utcSeconds) return null;
  const d = new Date(parseInt(utcSeconds) * 1000);
  return d.toISOString();
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
    const waypoints = navlog.map(wp => ({
      ident: wp.ident,
      lat: parseFloat(wp.pos_lat),
      lon: parseFloat(wp.pos_long),
      alt: parseInt(wp.altitude_feet || 0),
      type: wp.type
    }));

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
        std: parseTime(d.times?.sched_out),      // Scheduled block off
        sta: parseTime(d.times?.sched_in),        // Scheduled block on
        ete: parseInt(d.times?.est_time_enroute || 0), // seconds
        blockTime: parseInt(d.times?.est_block || 0)    // seconds
      },
      fuel: {
        units: d.params?.units || 'LBS',
        block: parseInt(d.fuel?.plan_ramp || 0),
        trip: parseInt(d.fuel?.enroute_burn || 0),
        taxi: parseInt(d.fuel?.taxi || 0),
        reserve: parseInt(d.fuel?.reserve || 0),
        alternate: parseInt(d.fuel?.alternate_burn || 0)
      },
      cruiseAlt: parseInt(d.general?.initial_altitude || 35000),
      cruiseSpeed: d.general?.cruise_tas,
      route: d.general?.route || '',
      waypoints,
      costIndex: d.general?.costindex,
      flightNumber: d.general?.flight_number || '',
      ofpId: d.params?.ofp_layout,
      fetchedAt: Date.now()
    };

    console.log(`[SimBrief] Loaded: ${plan.origin.icao} → ${plan.destination.icao} (${plan.aircraft.type})`);
    return plan;

  } catch (err) {
    console.error('[SimBrief] Fetch failed:', err.message);
    return null;
  }
}

module.exports = { fetchOFP };
