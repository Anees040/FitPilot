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
// Defaults to 2.5-flash rather than the 2.0-flash this project started on:
// 2.0 is being retired and already returns "limit: 0" on new free-tier keys,
// while 2.5-flash carries a documented free allowance (~250 requests/day).
//
// Overridable because a key can lose its allowance for one specific model, and
// because the 2.5 family is itself scheduled for retirement — when that
// happens the fix is a new model name in the Render dashboard, not a redeploy.
const MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';

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
// Ordered best-quality-first, then by how much free allowance each has:
// 2.5-flash (~250/day) reads a food photo more reliably than flash-lite, but
// flash-lite (~1000/day) keeps the app working after flash is exhausted.
// `flash-latest` tracks whatever Google currently ships, so it survives a model
// retirement that would otherwise take every pinned name down at once.
const FALLBACK_MODELS = [
  MODEL,
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-flash-latest',
  'gemini-2.0-flash',
].filter((m, i, all) => all.indexOf(m) === i);

let preferredModel = null;

// Models known to be out of quota, and when to try them again.
//
// Without this the fallback chain multiplies cost: every request walks all five
// models, so one user action can spend five quota units and a handful of failed
// requests can drain a day's free-tier allowance. A model that reports quota
// exhaustion is skipped entirely until its cooldown expires, which turns the
// chain back into roughly one API call per request.
const cooldowns = new Map(); // model -> epoch ms when it may be retried

// Quota on the free tier resets daily, but a shorter window is used so a
// temporary spike does not sideline a model for the rest of the day.
const QUOTA_COOLDOWN_MS = 30 * 60 * 1000;

function isCoolingDown(model) {
  const until = cooldowns.get(model);
  if (until === undefined) return false;
  if (Date.now() >= until) {
    cooldowns.delete(model);
    return false;
  }
  return true;
}

// Only quota failures earn a cooldown. A transient 503 overload should be
// retried promptly, not parked for half an hour.
function isQuotaExhausted(err) {
  const status = err?.status ?? err?.code;
  const msg = String(err?.message || err);
  return status === 429 || /quota|RESOURCE_EXHAUSTED/i.test(msg);
}

// Shown to the user when every model in the chain is refused. Deliberately
// actionable: this state is almost always a billing/quota problem on the key,
// not something the user did wrong.
function quotaMessage() {
  return (
    'AI features are temporarily unavailable — the daily AI allowance is used up. ' +
    'Please try again later.'
  );
}

// True when the failure is "this model cannot serve this right now" rather than
// "this request was bad" — only those are worth retrying on another model.
//
// 503 UNAVAILABLE is included deliberately: Google returns it when a model is
// briefly overloaded ("experiencing high demand"), which is transient and
// affects one model at a time. Without it a busy spell on the preferred model
// takes the whole feature down while the next model in the chain is idle.
function isModelUnavailable(err) {
  const status = err?.status ?? err?.code;
  const msg = String(err?.message || err);
  return (
    status === 429 ||
    status === 404 ||
    status === 403 ||
    status === 500 ||
    status === 503 ||
    /quota|RESOURCE_EXHAUSTED|not found|NOT_FOUND|unsupported|permission|UNAVAILABLE|overloaded|high demand|internal error/i.test(msg)
  );
}

// True when a 400 might be down to the thinking override.
//
// Matched on the status alone, not on the message: the API commonly answers
// with a bare "Request contains an invalid argument", naming nothing. Since
// this is only consulted when thinkingConfig was actually sent, retrying
// without it is safe — a 400 from any other cause simply fails again and is
// surfaced to the caller.
function isThinkingConfigRejected(err) {
  const status = err?.status ?? err?.code;
  return status === 400;
}

async function generate(request) {
  const order = preferredModel
    ? [preferredModel, ...FALLBACK_MODELS.filter((m) => m !== preferredModel)]
    : FALLBACK_MODELS;

  const available = order.filter((m) => !isCoolingDown(m));
  if (available.length === 0) {
    // Every model is known to be out of quota. Failing here costs nothing,
    // rather than spending five more doomed calls to learn the same thing.
    const err = new Error('All models are out of quota.');
    err.status = 429;
    throw err;
  }

  let lastError = null;
  for (const model of available) {
    try {
      return await callModel(model, request);
    } catch (err) {
      lastError = err;
      if (!isModelUnavailable(err)) throw err;
      if (isQuotaExhausted(err)) {
        cooldowns.set(model, Date.now() + QUOTA_COOLDOWN_MS);
        console.warn(`Gemini: ${model} out of quota, cooling down`);
      } else {
        console.warn(`Gemini: ${model} unavailable (${err?.status || '?'}), trying next`);
      }
      if (preferredModel === model) preferredModel = null;
    }
  }
  throw lastError || new Error('No Gemini model available.');
}

async function callModel(model, request) {
  try {
    const response = await ai.models.generateContent({ ...request, model });
    if (preferredModel !== model) {
      console.log(`Gemini: using model ${model}`);
      preferredModel = model;
    }
    return response;
  } catch (err) {
    // Only meaningful if we actually sent the override; otherwise there is
    // nothing to drop and the error stands.
    const sentThinking = request.config?.thinkingConfig !== undefined;
    if (!sentThinking || !isThinkingConfigRejected(err)) throw err;

    console.warn(`Gemini: ${model} rejected thinkingConfig, retrying without it`);
    const { thinkingConfig, ...config } = request.config;
    const response = await ai.models.generateContent({ ...request, config, model });
    preferredModel = model;
    return response;
  }
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
        // Additive and OPTIONAL. Absent when the model cannot judge it, which
        // the app stores as "unknown" rather than as zero grams.
        proteinG: { type: Type.NUMBER, description: 'Estimated protein in grams for the portion shown. Omit if unsure.' },
      },
      required: ['name', 'minKcal', 'maxKcal'],
    };

    const prompt =
      'Analyze this image. If it does NOT clearly show food or a beverage, return name="Not food" and 0 for calories. ' +
      'If it is food, identify it and estimate the calorie range for the portion shown. ' +
      'Be honest about uncertainty: the range must span at least plus/minus 15 percent around your central estimate. ' +
      'Also estimate protein in grams for the portion when the food is identifiable enough to judge it; omit proteinG entirely if you cannot. ' +
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


// ---------------------------------------------------------------------------
// In-app AI coach. Text in, text out — no responseSchema.
//
// Separate, larger quota from the photo endpoints: a conversation is many
// cheap turns, whereas a photo estimate is one expensive call.
// ---------------------------------------------------------------------------
const CHAT_DAILY_LIMIT = 40;
const chatUsage = new Map();

function chatQuota(req, res, next) {
  const deviceId = req.header('X-Device-Id') || req.ip || 'unknown';
  const today = new Date().toISOString().slice(0, 10);
  const entry = chatUsage.get(deviceId);
  if (entry && entry.day === today && entry.count >= CHAT_DAILY_LIMIT) {
    return res.status(429).json({
      error: 'Daily coach limit reached (' + CHAT_DAILY_LIMIT + ' messages/day). Try again tomorrow.',
    });
  }
  req.deviceId = deviceId;
  req.today = today;
  return next();
}

const COACH_SYSTEM_INSTRUCTION =
  'You are FitPilot Coach, the friendly in-app assistant of the FitPilot calorie & fitness app. ' +
  'ONLY answer questions about: fitness, exercise technique, workouts, calories, nutrition, weight goals, ' +
  'and how to use the FitPilot app (logging food by search/photo/label/barcode, burn plan, programs, progress, profile). ' +
  'If asked anything else, reply in ONE friendly sentence redirecting to fitness topics. ' +
  'Keep answers under 120 words, encouraging, plain language, metric units. ' +
  'Never give medical diagnoses or medication advice - suggest seeing a professional instead. ' +
  "Use the provided user context when relevant (today's calories, streak, active program). " +
  'When asked about diet or protein, prefer cheap local foods (daal, chana, soya chunks, eggs, dahi) over supplements.';

// Renders the caller's context into a line the model can actually use. Every
// field is optional — a guest with an empty profile still gets a useful coach.
function contextLine(context) {
  if (!context || typeof context !== 'object') return '';
  const bits = [];
  if (context.name) bits.push('Name: ' + context.name);
  if (Number.isFinite(context.todayKcal)) bits.push("Eaten today: " + Math.round(context.todayKcal) + ' kcal');
  if (Number.isFinite(context.targetKcal)) bits.push('Daily target: ' + Math.round(context.targetKcal) + ' kcal');
  if (Number.isFinite(context.toBurn)) bits.push('Still to burn: ' + Math.round(context.toBurn) + ' kcal');
  if (Number.isFinite(context.streakDays)) bits.push('Streak: ' + context.streakDays + ' days');
  if (context.activeProgram) bits.push('Active program: ' + context.activeProgram);
  if (Number.isFinite(context.proteinTodayG)) bits.push('Protein today: ' + Math.round(context.proteinTodayG) + ' g');
  if (Number.isFinite(context.proteinTargetG)) bits.push('Protein target: ' + Math.round(context.proteinTargetG) + ' g');
  if (bits.length === 0) return '';
  return 'Current user context - ' + bits.join('; ') + '.';
}

app.post('/api/chat', chatQuota, async (req, res) => {
  try {
    if (!ai) {
      return res.status(503).json({ error: 'Server is not configured (missing API key).' });
    }

    const rawMessages = Array.isArray(req.body.messages) ? req.body.messages : [];
    // Only the tail matters, and it bounds the token cost per request.
    const messages = rawMessages
      .filter((m) => m && typeof m.text === 'string' && m.text.trim())
      .slice(-20)
      .map((m) => ({
        role: m.role === 'model' ? 'model' : 'user',
        parts: [{ text: String(m.text).slice(0, 2000) }],
      }));

    if (messages.length === 0) {
      return res.status(400).json({ error: 'No message to answer.' });
    }

    const line = contextLine(req.body.context);
    const systemInstruction = line
      ? [COACH_SYSTEM_INSTRUCTION, line].join(' ')
      : COACH_SYSTEM_INSTRUCTION;

    const response = await generate({
      contents: messages,
      config: {
        systemInstruction,
        temperature: 0.7,
        // 2.5 models spend "thinking" tokens from this same budget before they
        // write anything, so a tight cap gets consumed by reasoning and the
        // reply arrives truncated mid-sentence. Disabling thinking keeps the
        // whole budget for the answer, and a coach reply is short prose that
        // gains nothing from a reasoning pass.
        thinkingConfig: { thinkingBudget: 0 },
        maxOutputTokens: 800,
      },
    });

    const reply = (response.text || '').trim();
    if (!reply) {
      return res.status(502).json({ error: 'Coach did not reply. Try again.' });
    }

    const entry = chatUsage.get(req.deviceId);
    if (!entry || entry.day !== req.today) {
      chatUsage.set(req.deviceId, { day: req.today, count: 1 });
    } else {
      entry.count += 1;
    }

    return res.json({ reply });
  } catch (error) {
    console.error('Error in coach chat:', error && error.message ? error.message : error);
    if (isModelUnavailable(error)) {
      return res.status(429).json({ error: quotaMessage() });
    }
    return res.status(500).json({
      error: 'Coach is unavailable right now.',
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
