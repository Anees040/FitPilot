const express = require('express');
const cors = require('cors');
require('dotenv').config();
const { GoogleGenAI, Type, Schema } = require('@google/genai');

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Initialize the Gemini client
// Note: It will automatically pick up GEMINI_API_KEY from environment
const ai = new GoogleGenAI();

app.post('/api/estimate-food', async (req, res) => {
  try {
    const { image, mimeType } = req.body;
    
    if (!image) {
      return res.status(400).json({ error: 'Missing image data in request.' });
    }

    const type = mimeType || 'image/jpeg';
    
    // Define the expected output schema
    const responseSchema = {
      type: Type.OBJECT,
      properties: {
        name: {
          type: Type.STRING,
          description: "A short, descriptive name of the food item in the image."
        },
        minKcal: {
          type: Type.INTEGER,
          description: "The minimum estimated calories (kcal) for the entire portion shown."
        },
        maxKcal: {
          type: Type.INTEGER,
          description: "The maximum estimated calories (kcal) for the entire portion shown."
        }
      },
      required: ["name", "minKcal", "maxKcal"]
    };

    const prompt = "Analyze this food image. Identify the food and estimate the total calorie range for the portion shown. Keep the name concise. Output must be valid JSON.";

    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: [
        {
          role: 'user',
          parts: [
            { text: prompt },
            {
              inlineData: {
                mimeType: type,
                data: image
              }
            }
          ]
        }
      ],
      config: {
        responseMimeType: "application/json",
        responseSchema: responseSchema,
        temperature: 0.1, // Keep it deterministic
      }
    });

    if (response.text) {
      const data = JSON.parse(response.text);
      return res.json(data);
    } else {
      return res.status(500).json({ error: 'Model did not return text.' });
    }
  } catch (error) {
    console.error('Error estimating food:', error);
    return res.status(500).json({ error: 'Failed to estimate food calories.' });
  }
});

// Export for serverless (like Vercel) or run locally
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
  });
}

module.exports = app;
