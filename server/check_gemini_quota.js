// Diagnostic: which Gemini models does this API key actually have quota for?
//
// Reads GEMINI_API_KEY from server/.env (or the environment) and sends a tiny
// text-only request to each candidate model. The key is never printed.
//
//   cd D:\fitpilot ; node server/check_gemini_quota.js
//
// Delete this file once the quota question is settled — it is a dev tool, not
// part of the running server.

const fs = require('fs');
const path = require('path');

function loadKey() {
  if (process.env.GEMINI_API_KEY) return process.env.GEMINI_API_KEY;
  const envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) return null;
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*GEMINI_API_KEY\s*=\s*(.*)\s*$/);
    if (m) return m[1].replace(/^["']|["']$/g, '').trim();
  }
  return null;
}

// Ordered as the server's own fallback chain, so what this prints matches what
// the app will actually reach for.
const CANDIDATES = [
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-flash-latest',
  'gemini-2.0-flash',
  'gemini-2.5-pro',
];

async function probe(key, model) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: 'Reply with the single word: ok' }] }],
        generationConfig: { maxOutputTokens: 8 },
      }),
    });
    const text = await res.text();
    if (res.ok) return { ok: true, note: 'quota available' };

    let detail = '';
    try {
      const j = JSON.parse(text);
      detail = j.error?.message || '';
    } catch (_) {
      detail = text;
    }
    const limit = detail.match(/limit: (\d+)/);
    if (res.status === 429) {
      return {
        ok: false,
        note: limit && limit[1] === '0'
          ? 'NO free-tier allowance (limit: 0) - needs billing or another model'
          : 'rate limited (has allowance, momentarily exhausted)',
      };
    }
    if (res.status === 404) return { ok: false, note: 'model not found for this key' };
    if (res.status === 400 && /API key not valid/i.test(detail)) {
      return { ok: false, note: 'API KEY REJECTED' };
    }
    return { ok: false, note: `HTTP ${res.status}: ${detail.slice(0, 90)}` };
  } catch (e) {
    return { ok: false, note: `request failed: ${e.message}` };
  }
}

(async () => {
  const key = loadKey();
  if (!key) {
    console.log('GEMINI_API_KEY not found in server/.env or the environment.');
    console.log('Set it, or run with:  $env:GEMINI_API_KEY="..." ; node server/check_gemini_quota.js');
    process.exit(1);
  }
  console.log(`Key loaded (${key.length} chars, value not shown). Probing models...\n`);

  const usable = [];
  for (const model of CANDIDATES) {
    const r = await probe(key, model);
    console.log(`  ${r.ok ? 'OK  ' : 'FAIL'}  ${model.padEnd(24)} ${r.note}`);
    if (r.ok) usable.push(model);
  }

  console.log('');
  if (usable.length === 0) {
    console.log('No candidate model has quota. Either enable billing on the');
    console.log('Google AI Studio / Cloud project behind this key, or issue a new key');
    console.log('from a project that still has free-tier access.');
  } else {
    console.log(`Usable now: ${usable.join(', ')}`);
    console.log(`Point the server at one of these by setting GEMINI_MODEL on Render.`);
  }
})();
