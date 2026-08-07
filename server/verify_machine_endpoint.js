/**
 * Live check for POST /api/analyze-machine.
 *
 * Sends a real machine photo to a running server and prints the parsed result,
 * so you can confirm the endpoint works before testing on a phone.
 *
 * Usage (from the repo root):
 *   node server/verify_machine_endpoint.js
 *   node server/verify_machine_endpoint.js http://localhost:3000
 *   node server/verify_machine_endpoint.js <url> assets/exercise_media/leg_press.webp
 *
 * No API key is needed here: the server holds it.
 */
const fs = require('fs');
const path = require('path');

const BASE = (process.argv[2] || 'https://fitpilot-js0j.onrender.com').replace(/\/$/, '');
const IMAGE = process.argv[3] || 'assets/exercise_media/lat_pulldown.webp';
const DEVICE_ID = 'verify-script-local';

function mimeFor(file) {
  const ext = path.extname(file).toLowerCase();
  if (ext === '.png') return 'image/png';
  if (ext === '.webp') return 'image/webp';
  return 'image/jpeg';
}

async function main() {
  const imgPath = path.resolve(process.cwd(), IMAGE);
  if (!fs.existsSync(imgPath)) {
    console.error(`Image not found: ${imgPath}`);
    process.exit(1);
  }

  console.log(`Server : ${BASE}`);
  console.log(`Image  : ${IMAGE}`);

  // Render's free tier sleeps; wake it first so the real call isn't the one
  // that eats the cold start.
  process.stdout.write('Health : ');
  const startedHealth = Date.now();
  try {
    const h = await fetch(`${BASE}/api/health`, {
      signal: AbortSignal.timeout(90000),
    });
    const body = await h.json();
    console.log(
      `${h.status} in ${Date.now() - startedHealth}ms (keyConfigured=${body.keyConfigured})`,
    );
    if (body.keyConfigured === false) {
      console.error('\nGEMINI_API_KEY is not set on this server. Set it and redeploy.');
      process.exit(1);
    }
  } catch (e) {
    console.log(`unreachable (${e.message})`);
    process.exit(1);
  }

  const imageBase64 = fs.readFileSync(imgPath).toString('base64');
  console.log(`Payload: ${(imageBase64.length / 1024).toFixed(0)} KB base64\n`);

  process.stdout.write('Analyzing... ');
  const started = Date.now();
  let res;
  try {
    res = await fetch(`${BASE}/api/analyze-machine`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Device-Id': DEVICE_ID,
      },
      body: JSON.stringify({ imageBase64, mimeType: mimeFor(IMAGE) }),
      signal: AbortSignal.timeout(90000),
    });
  } catch (e) {
    console.log(`FAILED (${e.message})`);
    process.exit(1);
  }
  console.log(`HTTP ${res.status} in ${Date.now() - started}ms\n`);

  const text = await res.text();
  if (res.status === 404) {
    console.error('404 — this server does not have the endpoint yet. Push and redeploy.');
    process.exit(1);
  }
  if (!res.ok) {
    console.error(text.slice(0, 600));
    process.exit(1);
  }

  let data;
  try {
    data = JSON.parse(text);
  } catch {
    console.error('Response was not JSON:\n' + text.slice(0, 600));
    process.exit(1);
  }

  // Assert the contract the Flutter model parses.
  const problems = [];
  const wantArrays = [
    'primaryMuscles',
    'secondaryMuscles',
    'howToUse',
    'commonMistakes',
    'safetyTips',
    'suggestedExerciseKeywords',
  ];
  if (typeof data.isGymMachine !== 'boolean') problems.push('isGymMachine is not a boolean');
  if (typeof data.machineName !== 'string' || !data.machineName) problems.push('machineName missing');
  if (typeof data.confidence !== 'number') problems.push('confidence is not a number');
  for (const k of wantArrays) {
    if (!Array.isArray(data[k])) problems.push(`${k} is not an array`);
  }

  console.log(`isGymMachine : ${data.isGymMachine}`);
  console.log(`machineName  : ${data.machineName}`);
  console.log(`confidence   : ${data.confidence}`);
  console.log(`primary      : ${(data.primaryMuscles || []).join(', ')}`);
  console.log(`secondary    : ${(data.secondaryMuscles || []).join(', ')}`);
  console.log(`keywords     : ${(data.suggestedExerciseKeywords || []).join(', ')}`);
  console.log(`\nHow to use (${(data.howToUse || []).length} steps):`);
  (data.howToUse || []).forEach((s, i) => console.log(`  ${i + 1}. ${s}`));
  console.log(`\nCommon mistakes (${(data.commonMistakes || []).length}):`);
  (data.commonMistakes || []).forEach((s) => console.log(`  - ${s}`));
  console.log(`\nSafety tips (${(data.safetyTips || []).length}):`);
  (data.safetyTips || []).forEach((s) => console.log(`  - ${s}`));

  if (problems.length) {
    console.error('\nCONTRACT PROBLEMS:');
    problems.forEach((p) => console.error(`  - ${p}`));
    process.exit(1);
  }
  console.log('\nOK — shape matches what MachineAnalysis.fromJson expects.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
