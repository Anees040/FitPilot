#!/usr/bin/env node
/**
 * Fetches one shared dish photo per image_key from Wikimedia, resizes it to a
 * square thumbnail, and writes it into assets/food_images/ alongside a
 * manifest and a credits file.
 *
 * Why it works this way:
 *   commons.wikimedia.org is unreachable from this network (hostname-level
 *   block), but en.wikipedia.org/w/api.php serves metadata for Commons-hosted
 *   files (imagerepository: "shared") and upload.wikimedia.org serves the
 *   bytes. So we go: article title -> lead image -> imageinfo -> bytes.
 *
 * Metadata queries are BATCHED (50 titles per request) and retried with
 * backoff. Querying one title at a time trips Wikimedia's anonymous rate
 * limit and returns 429 for the whole run.
 *
 * License handling: the license and author are read from the live API response
 * for every single file. A file whose license is not on the free whitelist is
 * dropped, never guessed, and never shipped.
 *
 * Usage:
 *   node tool/fetch_food_images.mjs            # fetch only missing keys
 *   node tool/fetch_food_images.mjs --force    # re-fetch everything
 *   node tool/fetch_food_images.mjs --only=biryani,pizza
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '..');
const SOURCES = path.join(HERE, 'food_image_sources.csv');
const OUT_DIR = path.join(REPO, 'assets', 'food_images');

const API = 'https://en.wikipedia.org/w/api.php';
const UA = 'FitPilot-asset-fetcher/1.0 (final-year project; contact via repo)';

const SIZE = 320;
const WEBP_QUALITY = 75;
const REQUEST_WIDTH = 640; // fetch 2x then downscale for a sharper result
const BATCH = 50; // max titles per API request
const PAUSE_MS = 400; // between API requests, to stay well under the limit

/** Licenses we are allowed to bundle. Everything else is dropped. */
const FREE_LICENSE = /^(cc0|cc[ -]by|public domain|pd|no restrictions)/i;

const args = process.argv.slice(2);
const force = args.includes('--force');
const onlyArg = args.find((a) => a.startsWith('--only='));
const only = onlyArg ? new Set(onlyArg.slice(7).split(',').map((s) => s.trim())) : null;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Strips the HTML Wikimedia returns in the Artist field down to plain text. */
function plainText(html) {
  if (!html) return '';
  return html
    .replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

/** GET with backoff on 429/5xx, honouring Retry-After when present. */
async function getWithRetry(url, attempts = 5) {
  let wait = 1000;
  for (let i = 0; i < attempts; i++) {
    const res = await fetch(url, { headers: { 'User-Agent': UA } });
    if (res.ok) return res;
    if (res.status !== 429 && res.status < 500) {
      throw new Error(`HTTP ${res.status}`);
    }
    const retryAfter = Number(res.headers.get('retry-after'));
    const delay = Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : wait;
    process.stdout.write(`  . rate limited, waiting ${Math.round(delay / 1000)}s\n`);
    await sleep(delay);
    wait = Math.min(wait * 2, 30000);
  }
  throw new Error(`HTTP retries exhausted`);
}

async function api(params) {
  const url = new URL(API);
  for (const [k, v] of Object.entries({ format: 'json', formatversion: '2', ...params })) {
    url.searchParams.set(k, v);
  }
  const res = await getWithRetry(url);
  await sleep(PAUSE_MS);
  return res.json();
}

function chunk(list, n) {
  const out = [];
  for (let i = 0; i < list.length; i += n) out.push(list.slice(i, i + n));
  return out;
}

/**
 * `pageimages` returns filenames with underscores ("Annapurna_Naan.jpg") while
 * `imageinfo` echoes page titles with spaces ("File:Annapurna Naan.jpg").
 * Both maps are keyed through this so lookups match.
 */
const fileKey = (name) => name.replace(/_/g, ' ').trim();

/**
 * Batch-resolves article titles to their lead image filenames.
 * Returns Map<normalisedTitle, filename>. Handles the `normalized` and
 * `redirects` mappings the API applies so lookups by the original title work.
 */
async function leadImages(articles) {
  const result = new Map();
  for (const group of chunk(articles, BATCH)) {
    const json = await api({
      action: 'query',
      titles: group.join('|'),
      prop: 'pageimages',
      piprop: 'name',
      pilimit: String(BATCH),
      redirects: '1',
    });
    const q = json?.query ?? {};

    // title -> resolved title, following normalisation then redirects
    const alias = new Map();
    for (const n of q.normalized ?? []) alias.set(n.from, n.to);
    for (const r of q.redirects ?? []) alias.set(r.from, r.to);

    const byTitle = new Map();
    for (const page of q.pages ?? []) {
      if (page.missing || !page.pageimage) continue;
      byTitle.set(page.title, page.pageimage);
    }

    for (const original of group) {
      let title = original;
      for (let hop = 0; hop < 4 && alias.has(title); hop++) title = alias.get(title);
      const file = byTitle.get(title) ?? byTitle.get(original);
      if (file) result.set(original, file);
    }
  }
  return result;
}

/** Batch-reads url + license + author for File: titles. Unusable ones are omitted. */
async function fileInfos(filenames) {
  const result = new Map();
  for (const group of chunk(filenames, BATCH)) {
    const json = await api({
      action: 'query',
      titles: group.map((f) => `File:${f}`).join('|'),
      prop: 'imageinfo',
      iiprop: 'url|extmetadata|mime',
      iiurlwidth: String(REQUEST_WIDTH),
    });
    for (const page of json?.query?.pages ?? []) {
      const info = page?.imageinfo?.[0];
      if (!info) continue;

      const mime = info.mime ?? '';
      if (!/^image\/(jpeg|png|webp)$/.test(mime)) continue; // skip svg/tif/gif

      const meta = info.extmetadata ?? {};
      const license = plainText(meta.LicenseShortName?.value) || 'unknown';
      if (!FREE_LICENSE.test(license)) continue;

      const filename = fileKey(page.title.replace(/^File:/, ''));
      result.set(filename, {
        file: filename,
        url: info.thumburl || info.url,
        license,
        author: plainText(meta.Artist?.value) || 'Unknown',
        source: info.descriptionurl ?? '',
      });
    }
  }
  return result;
}

async function download(url) {
  const res = await getWithRetry(url);
  return Buffer.from(await res.arrayBuffer());
}

function parseCsv(text) {
  const rows = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const comma = line.indexOf(',');
    if (comma < 0) continue;
    const key = line.slice(0, comma).trim();
    const candidates = line
      .slice(comma + 1)
      .split('|')
      .map((s) => s.trim())
      .filter(Boolean);
    if (key && candidates.length) rows.push({ key, candidates });
  }
  return rows;
}

async function main() {
  const all = parseCsv(await fs.readFile(SOURCES, 'utf8'));
  await fs.mkdir(OUT_DIR, { recursive: true });

  // Credits carry over so a partial re-run never loses attribution for files
  // it did not touch.
  const creditsPath = path.join(OUT_DIR, 'credits.json');
  let credits = {};
  try {
    credits = JSON.parse(await fs.readFile(creditsPath, 'utf8'));
  } catch {
    credits = {};
  }

  // Decide up front which keys need work, so the batched metadata queries only
  // cover articles we actually intend to download.
  const todo = [];
  let skipped = 0;
  for (const row of all) {
    if (only && !only.has(row.key)) continue;
    if (!force) {
      const exists = await fs
        .access(path.join(OUT_DIR, `${row.key}.webp`))
        .then(() => true)
        .catch(() => false);
      if (exists && credits[row.key]) {
        skipped++;
        continue;
      }
    }
    todo.push(row);
  }

  const failed = [];
  let fetched = 0;

  if (todo.length) {
    const articles = [...new Set(todo.flatMap((r) => r.candidates))];
    process.stdout.write(`resolving ${articles.length} articles for ${todo.length} keys\n`);
    const leads = await leadImages(articles);

    const filenames = [...new Set([...leads.values()])];
    process.stdout.write(`reading license metadata for ${filenames.length} files\n\n`);
    const infos = await fileInfos(filenames);

    for (const { key, candidates } of todo) {
      let info = null;
      let usedArticle = null;
      for (const article of candidates) {
        const filename = leads.get(article);
        if (!filename) continue;
        const candidate = infos.get(fileKey(filename));
        if (!candidate) continue;
        info = candidate;
        usedArticle = article;
        break;
      }

      if (!info) {
        failed.push(key);
        process.stdout.write(`  ! ${key}: no free image found\n`);
        continue;
      }

      const outFile = path.join(OUT_DIR, `${key}.webp`);
      try {
        const bytes = await download(info.url);
        await sharp(bytes)
          .resize(SIZE, SIZE, { fit: 'cover', position: 'attention' })
          .webp({ quality: WEBP_QUALITY })
          .toFile(outFile);

        const { size } = await fs.stat(outFile);
        credits[key] = {
          file: info.file,
          article: usedArticle,
          license: info.license,
          author: info.author,
          source: info.source,
        };
        fetched++;
        process.stdout.write(
          `  + ${key.padEnd(16)} ${String(Math.round(size / 1024)).padStart(3)} KB  ${info.license}\n`,
        );
      } catch (e) {
        failed.push(key);
        process.stdout.write(`  ! ${key}: ${e.message}\n`);
      }
    }
  }

  // Manifest is the list of keys that actually have a bundled file, so the app
  // can decide at runtime whether to use the asset or fall back to an icon.
  const files = (await fs.readdir(OUT_DIR)).filter((f) => f.endsWith('.webp'));
  const keys = files.map((f) => f.replace(/\.webp$/, '')).sort();
  await fs.writeFile(
    path.join(OUT_DIR, 'manifest.json'),
    `${JSON.stringify({ version: 1, keys }, null, 2)}\n`,
  );

  const orderedCredits = Object.fromEntries(
    Object.keys(credits)
      .filter((k) => keys.includes(k))
      .sort()
      .map((k) => [k, credits[k]]),
  );
  await fs.writeFile(creditsPath, `${JSON.stringify(orderedCredits, null, 2)}\n`);

  let total = 0;
  for (const f of files) total += (await fs.stat(path.join(OUT_DIR, f))).size;

  process.stdout.write(
    `\nfetched=${fetched} skipped=${skipped} failed=${failed.length} ` +
      `bundled=${keys.length} total=${(total / 1024 / 1024).toFixed(2)} MB\n`,
  );
  if (failed.length) process.stdout.write(`missing: ${failed.join(', ')}\n`);
}

main().catch((e) => {
  process.stderr.write(`${e.stack ?? e}\n`);
  process.exit(1);
});
