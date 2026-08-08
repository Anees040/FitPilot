const express = require('express');
const cors = require('cors');
require('dotenv').config();
const { GoogleGenAI, Type } = require('@google/genai');

const app = express();
app.use(cors());
app.use(express.json({ limit: '20mb' }));

// ---------------------------------------------------------------------------
// Gemini client
// FIX: the SDK constructor REQUIRES an options object. Calling new GoogleGenAI()
// with no arguments crashes at boot.
// ---------------------------------------------------------------------------
const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
  console.warn(
    'WARNING: GEMINI_API_KEY is not set. /api/estimate-food will return 503. ' +
    'Set it in Render > your service > Environment.'
  );
}
const ai = apiKey ? new GoogleGenAI({ apiKey }) : null;

// Model used by every AI endpoint.
//
// Defaults to the model this project has always used, so leaving GEMINI_MODEL
// unset changes nothing. It is overridable because a key can lose free-tier
// allowance for one specific model ("limit: 0" 429s) — when that happens the
// fix is a new model name in the Render dashboard, not a redeploy.
const MODEL = process.env.GEMINI_MODEL || 'gemini-2.0-flash';

// ---------------------------------------------------------------------------
// Model fallback chain.
//
// Google cut free-tier allowances to zero for most models (Dec 2025), so a key
// that worked yesterday can start returning 429 "limit: 0" for one specific
// model while others still answer. Pinning a single model makes every AI
// feature in the app fail at once.
//
// generate() walks this chain and returns the first model that answers. The
// winner is cached so the happy path stays a single API call; the cache is
// dropped as soon as that model starts failing again.
// ---------------------------------------------------------------------------
const FALLBACK_MODELS = [
  MODEL,
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-flash-latest',
  'gemini-2.0-flash-lite',
].filter((m, i, all) => all.indexOf(m) === i);

let preferredModel = null;

// Shown to the user when every model in the chain is refused. Deliberately
// actionable: this state is almost always a billing/quota problem on the key,
// not something the user did wrong.
function quotaMessage() {
  return (
    'AI features are temporarily unavailable — the daily AI allowance is used up. ' +
    'Please try again later.'
  );
}

// True when the failure is "this model is unavailable to this key" rather than
// "this request was bad" — only those are worth retrying on another model.
function isModelUnavailable(err) {
  const status = err?.status ?? err?.code;
  const msg = String(err?.message || err);
  return (
    status === 429 ||
    status === 404 ||
    status === 403 ||
    /quota|RESOURCE_EXHAUSTED|not found|NOT_FOUND|unsupported|permission/i.test(msg)
  );
}

async function generate(request) {
  const order = preferredModel
    ? [preferredModel, ...FALLBACK_MODELS.filter((m) => m !== preferredModel)]
    : FALLBACK_MODELS;

  let lastError = null;
  for (const model of order) {
    try {
      const response = await ai.models.generateContent({ ...request, model });
      if (preferredModel !== model) {
        console.log(`Gemini: using model ${model}`);
        preferredModel = model;
      }
      return response;
    } catch (err) {
      lastError = err;
      if (!isModelUnavailable(err)) throw err;
      console.warn(`Gemini: ${model} unavailable (${err?.status || '?'}), trying next`);
      if (preferredModel === model) preferredModel = null;
    }
  }
  throw lastError || new Error('No Gemini model available.');
}

// ---------------------------------------------------------------------------
// Daily quota: 3 photo estimates per device per day (in-memory)
// ---------------------------------------------------------------------------
const DAILY_LIMIT = 20;
const usage = new Map(); // deviceId -> { day: 'YYYY-MM-DD', count: number }

function quota(req, res, next) {
  const deviceId = req.header('X-Device-Id') || req.ip || 'unknown';
  const today = new Date().toISOString().slice(0, 10);
  const entry = usage.get(deviceId);
  if (entry && entry.day === today && entry.count >= DAILY_LIMIT) {
    return res.status(429).json({
      error: 'Daily photo limit reached (' + DAILY_LIMIT + '/day). Try again tomorrow.',
    });
  }
  req.deviceId = deviceId;
  req.today = today;
  return next();
}

// Health check
app.get('/api/health', (req, res) => {
  res.json({ ok: true, keyConfigured: Boolean(apiKey) });
});

app.post('/api/estimate-food', quota, async (req, res) => {
  try {
    if (!ai) {
      return res.status(503).json({ error: 'Server is not configured (missing API key).' });
    }
    const { image, mimeType } = req.body;
    if (!image) {
      return res.status(400).json({ error: 'Missing image data in request.' });
    }

    const responseSchema = {
      type: Type.OBJECT,
      properties: {
        name: { type: Type.STRING, description: 'Short descriptive name of the food item.' },
        portionGrams: { type: Type.INTEGER, description: 'Estimated portion weight in grams for the portion shown.' },
        minKcal: { type: Type.INTEGER, description: 'Minimum estimated kcal for the entire portion shown.' },
        maxKcal: { type: Type.INTEGER, description: 'Maximum estimated kcal for the entire portion shown.' },
        notes: { type: Type.STRING, description: 'One short sentence on what drives the uncertainty.' },
      },
      required: ['name', 'minKcal', 'maxKcal'],
    };

    const prompt =
      'Analyze this image. If it does NOT clearly show food or a beverage, return name="Not food" and 0 for calories. ' +
      'If it is food, identify it and estimate the calorie range for the portion shown. ' +
      'Be honest about uncertainty: the range must span at least plus/minus 15 percent around your central estimate. ' +
      'Keep the name concise.';

    const response = await generate({
      contents: [
        {
          role: 'user',
          parts: [
            { text: prompt },
            { inlineData: { mimeType: mimeType || 'image/jpeg', data: image } },
          ],
        },
      ],
      config: {
        responseMimeType: 'application/json',
        responseSchema,
        temperature: 0.1,
      },
    });

    if (!response.text) {
      return res.status(502).json({ error: 'Model did not return a result.' });
    }

    let responseText = response.text;
    // Strip markdown formatting if the model wrapped the JSON
    if (responseText.startsWith('```')) {
      responseText = responseText.replace(/^```(?:json)?\n?/g, '').replace(/\n?```$/g, '');
    }

    const data = JSON.parse(responseText);

    // Enforce range honesty server-side: widen degenerate ranges to +/-15%.
    if (
      typeof data.minKcal === 'number' &&
      typeof data.maxKcal === 'number' &&
      data.minKcal >= data.maxKcal
    ) {
      const mid = Math.round((data.minKcal + data.maxKcal) / 2);
      data.minKcal = Math.round(mid * 0.85);
      data.maxKcal = Math.round(mid * 1.15);
    }

    const entry = usage.get(req.deviceId);
    if (!entry || entry.day !== req.today) {
      usage.set(req.deviceId, { day: req.today, count: 1 });
    } else {
      entry.count += 1;
    }

    return res.json(data);
  } catch (error) {
    console.error('Error estimating food:', error && error.message ? error.message : error);
    if (isModelUnavailable(error)) {
      return res.status(429).json({ error: quotaMessage() });
    }
    return res.status(500).json({
      error: 'Failed to estimate food calories.',
      details: error && error.message ? error.message : String(error)
    });
  }
});

// ---------------------------------------------------------------------------
// Gym machine identification + coaching.
// Same quota map and model as /api/estimate-food; counted only after success.
// ---------------------------------------------------------------------------
app.post('/api/analyze-machine', quota, async (req, res) => {
  try {
    if (!ai) {
      return res.status(503).json({ error: 'Server is not configured (missing API key).' });
    }
    // The Flutter client sends `imageBase64`; `image` is accepted so this
    // endpoint stays call-compatible with the food endpoint's payload shape.
    const image = req.body.imageBase64 || req.body.image;
    const { mimeType } = req.body;
    if (!image) {
      return res.status(400).json({ error: 'Missing image data in request.' });
    }

    const stringArray = (description, min, max) => ({
      type: Type.ARRAY,
      description,
      minItems: min,
      maxItems: max,
      items: { type: Type.STRING },
    });

    const responseSchema = {
      type: Type.OBJECT,
      properties: {
        isGymMachine: {
          type: Type.BOOLEAN,
          description: 'True only if the photo shows gym or fitness equipment.',
        },
        machineName: {
          type: Type.STRING,
          description: 'Common name of the machine, e.g. "Lat Pulldown Machine".',
        },
        confidence: {
          type: Type.NUMBER,
          description: 'How certain the identification is, from 0 to 1.',
        },
        primaryMuscles: stringArray('Main muscles the machine trains.', 1, 3),
        secondaryMuscles: stringArray('Supporting muscles worked.', 0, 3),
        howToUse: stringArray(
          'Five to seven short beginner steps, in order, from setup to finish. No step numbers in the text.',
          5,
          7
        ),
        commonMistakes: stringArray('Exactly three common beginner mistakes.', 3, 3),
        safetyTips: stringArray('Exactly two safety tips.', 2, 2),
        suggestedExerciseKeywords: stringArray(
          'Three to six generic exercise names for this machine, e.g. "lat pulldown", "chest press".',
          3,
          6
        ),
      },
      required: ['isGymMachine', 'machineName', 'confidence'],
    };

    const prompt =
      'Identify the gym or fitness machine in this photo and teach a complete beginner how to use it safely. ' +
      'Write for someone who has never touched this machine: plain language, no jargon, one action per step. ' +
      'Steps must run in order from setup (seat, pin, grip) through the working reps to finishing safely. ' +
      'Use anatomical muscle names such as Chest, Back, Lats, Shoulders, Biceps, Triceps, Core, Quads, Hamstrings, Glutes, Legs. ' +
      'If the photo does NOT show gym or fitness equipment, set isGymMachine=false, machineName to a short description ' +
      'of what is actually shown, confidence to your certainty about that, and leave every list empty.';

    const response = await generate({
      contents: [
        {
          role: 'user',
          parts: [
            { text: prompt },
            { inlineData: { mimeType: mimeType || 'image/jpeg', data: image } },
          ],
        },
      ],
      config: {
        responseMimeType: 'application/json',
        responseSchema,
        temperature: 0.2,
      },
    });

    if (!response.text) {
      return res.status(502).json({ error: 'Model did not return a result.' });
    }

    let responseText = response.text;
    if (responseText.startsWith('```')) {
      responseText = responseText.replace(/^```(?:json)?\n?/g, '').replace(/\n?```$/g, '');
    }

    const data = JSON.parse(responseText);

    // Normalise so the client never has to defend against a missing list.
    const asList = (value) =>
      Array.isArray(value) ? value.filter((v) => typeof v === 'string' && v.trim()) : [];
    data.isGymMachine = data.isGymMachine === true;
    data.machineName = typeof data.machineName === 'string' ? data.machineName : '';
    data.confidence =
      typeof data.confidence === 'number' ? Math.min(1, Math.max(0, data.confidence)) : 0;
    data.primaryMuscles = asList(data.primaryMuscles);
    data.secondaryMuscles = asList(data.secondaryMuscles);
    data.howToUse = asList(data.howToUse);
    data.commonMistakes = asList(data.commonMistakes);
    data.safetyTips = asList(data.safetyTips);
    data.suggestedExerciseKeywords = asList(data.suggestedExerciseKeywords);

    // A "not a machine" answer is still a successful call, so it counts against
    // the quota exactly like a hit — the model work was done either way.
    const entry = usage.get(req.deviceId);
    if (!entry || entry.day !== req.today) {
      usage.set(req.deviceId, { day: req.today, count: 1 });
    } else {
      entry.count += 1;
    }

    return res.json(data);
  } catch (error) {
    console.error('Error analyzing machine:', error && error.message ? error.message : error);
    if (isModelUnavailable(error)) {
      return res.status(429).json({ error: quotaMessage() });
    }
    return res.status(500).json({
      error: 'Failed to analyze the machine.',
      details: error && error.message ? error.message : String(error),
    });
  }
});

if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log('Server listening on port ' + PORT);
  });
}

module.exports = app;
