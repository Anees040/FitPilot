const { GoogleGenAI } = require('@google/genai');
require('dotenv').config();

async function run() {
  const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
  try {
    const response = await ai.models.list();
    console.log(response.map(m => m.name));
  } catch (e) {
    console.error("ERROR", e);
  }
}
run();
