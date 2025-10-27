
const express = require('express');
const dotenv = require('dotenv');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const cors = require('cors'); // Import cors

dotenv.config();

const app = express();
app.use(cors()); // Use cors middleware
app.use(express.json());

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

if (!GEMINI_API_KEY) {
  console.error('GEMINI_API_KEY is not set in the .env file');
  process.exit(1);
}

const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

app.post('/generate-example', async (req, res) => {
  const { word, meaning } = req.body;

  if (!word || !meaning) {
    return res.status(400).json({ error: 'Word and meaning are required.' });
  }

  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
    const prompt = `Generate 3 example sentences using the English word "${word}" with its Korean meaning "${meaning}". Provide the output in Korean. Each example sentence should be on a new line, followed by its Korean translation on the next line. For example:
English sentence 1.
한국어 번역 1.
English sentence 2.
한국어 번역 2.
English sentence 3.
한국어 번역 3.`;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    res.json({ generatedText: text });
  } catch (error) {
    console.error('Gemini API call failed:', error);
    res.status(500).json({ error: 'Failed to generate example from Gemini API.', details: error.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
