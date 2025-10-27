const dotenv = require('dotenv');
const axios = require('axios');

dotenv.config();

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

if (!GEMINI_API_KEY) {
  console.error('GEMINI_API_KEY is not set in the .env file');
  process.exit(1);
}

async function listModels() {
  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY}`;
    const response = await axios.get(url);
    const models = response.data.models;

    console.log('Available Gemini Models:');
    if (models && models.length > 0) {
      for (const model of models) {
        const supportsGenerateContent = model.supportedGenerationMethods && model.supportedGenerationMethods.includes('generateContent');
        console.log(`- ${model.name} (DisplayName: ${model.displayName || 'N/A'}, Supports generateContent: ${supportsGenerateContent})`);
      }
    } else {
      console.log('No models found or API key might be invalid/restricted.');
    }
  } catch (error) {
    console.error('Error listing models:', error.response ? error.response.data : error.message);
  }
}

listModels();