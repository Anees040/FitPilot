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

// ---------------------------------------------------------------------------
// Daily quota: 3 photo estimates per device per day (in-memory)
// ---------------------------------------------------------------------------
const DAILY_LIMIT = 20;
const usage = new Map(); // deviceId -> { day: 'YYYY-MM-DD', count: number }

function quota(req, res, next) {
  const deviceId = req.header('X-Device-Id') || req.ip || 'unknown';
  const today = new Date().toISOString().slice(0, 10);
  const entry = usage.get(deviceId);
  if (!entry || entry.day !== today) {
    usage.set(deviceId, { day: today, count: 1 });
    return next();
  }
  if (entry.count >= DAILY_LIMIT) {
    return res.status(429).json({
      error: 'Daily photo limit reached (' + DAILY_LIMIT + '/day). Try again tomorrow.',
    });
  }
  entry.count += 1;
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

    const response = await ai.models.generateContent({
      model: 'gemini-2.0-flash',
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

    return res.json(data);
  } catch (error) {
    console.error('Error estimating food:', error && error.message ? error.message : error);
    return res.status(500).json({ 
      error: 'Failed to estimate food calories.',
      details: error && error.message ? error.message : String(error)
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
