// Run: node test-simbrief.js
const axios = require('axios');

const PILOT_ID = '1246391';
const URL = `https://www.simbrief.com/api/xml.fetcher.php?userid=${PILOT_ID}&json=v2`;

async function main() {
  const res = await axios.get(URL, { timeout: 15000 });
  const d = res.data;

  console.log('\n=== RAW TIMES OBJECT ===');
  console.log(JSON.stringify(d.times, null, 2));

  console.log('\n=== RAW ORIGIN ===');
  console.log(JSON.stringify(d.origin, null, 2));

  console.log('\n=== RAW DESTINATION ===');
  console.log(JSON.stringify(d.destination, null, 2));

  console.log('\n=== GENERAL (schedule fields) ===');
  console.log('sched_out:', d.general?.sched_out);
  console.log('sched_in:', d.general?.sched_in);

  console.log('\n=== PARAMS ===');
  console.log(JSON.stringify(d.params, null, 2));
}

main().catch(console.error);
