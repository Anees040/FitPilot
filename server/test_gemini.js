const { GoogleGenAI, Type } = require('@google/genai');
require('dotenv').config();

async function run() {
  const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
  const responseSchema = {
    type: Type.OBJECT,
    properties: {
      name: { type: Type.STRING, description: 'Short descriptive name of the food item.' },
      portionGrams: { type: Type.INTEGER, description: 'Estimated portion weight in grams.' },
      minKcal: { type: Type.INTEGER, description: 'Minimum estimated kcal.' },
      maxKcal: { type: Type.INTEGER, description: 'Maximum estimated kcal.' },
      notes: { type: Type.STRING, description: 'One short sentence on what drives the uncertainty.' },
    },
    required: ['name', 'minKcal', 'maxKcal'],
  };

  try {
    const response = await ai.models.generateContent({
      model: 'gemini-1.5-flash',
      contents: [
        {
          role: 'user',
          parts: [
            { text: 'Analyze this food' },
            { inlineData: { mimeType: 'image/png', data: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=' } },
          ],
        },
      ],
      config: {
        responseMimeType: 'application/json',
        responseSchema,
        temperature: 0.1,
      },
    });
    console.log(response.text);
  } catch (e) {
    console.error("ERROR", e);
  }
}
run();
