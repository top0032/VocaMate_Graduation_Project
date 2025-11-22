const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const textToSpeech = require('@google-cloud/text-to-speech');

admin.initializeApp();

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// API 키 설정
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || functions.config().gemini?.key;

// 클라이언트 초기화
const ttsClient = new textToSpeech.TextToSpeechClient();

// ==========================================
// 1. Gemini 예문 생성 API (프롬프트 강력 수정)
// ==========================================
app.post('/generate-example', async (req, res) => {
  if (!GEMINI_API_KEY) {
    return res.status(500).json({ error: 'Server Error: API Key is missing.' });
  }

  const { word, meaning } = req.body;
  if (!word || !meaning) {
    return res.status(400).json({ error: 'Word and meaning are required.' });
  }

  try {
    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
    // 1.5-pro 모델 사용 (지시 이행 능력이 좋음)
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-pro' });
    
    // 💡 [수정된 프롬프트] 원하는 출력 형식을 예시와 함께 명확히 제시
    const prompt = `
    Role: Professional English Teacher.
    Task: Create sentences for the word "${word}" (meaning: "${meaning}") at 3 difficulty levels.
    
    Strict Output Format Rules:
    1. Do NOT add any introductory text or markdown like "**".
    2. Provide exactly 3 sets (Beginner, Intermediate, Advanced).
    3. The format must be exactly as follows:

    [초급]
    (Write a simple English sentence here)
    (Write the Korean translation here)

    [중급]
    (Write a business/daily English sentence here)
    (Write the Korean translation here)

    [고급]
    (Write a formal/academic English sentence here)
    (Write the Korean translation here)
    `;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    res.json({ generatedText: text });

  } catch (error) {
    console.error('Gemini API call failed:', error);
    res.status(500).json({ error: 'Failed to generate example.', details: error.message });
  }
});

// ==========================================
// 2. 고품질 TTS 생성 API (기존 유지)
// ==========================================
app.post('/generate-speech', async (req, res) => {
  const { text, speed } = req.body;
  if (!text) return res.status(400).json({ error: 'Missing text' });

  const hasKorean = /[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]/.test(text);

  let languageCode = 'en-US';
  let voiceName = 'en-US-Neural2-D';

  if (hasKorean) {
    languageCode = 'ko-KR';
    voiceName = 'ko-KR-Neural2-C'; 
  }

  const request = {
    input: { text: text },
    voice: { languageCode: languageCode, name: voiceName },
    audioConfig: { audioEncoding: 'MP3', speakingRate: speed || 1.0 },
  };

  try {
    const [response] = await ttsClient.synthesizeSpeech(request);
    res.json({ audioContent: response.audioContent.toString('base64') });
  } catch (error) {
    console.error('TTS Error:', error);
    res.status(500).json({ error: error.message });
  }
});

exports.api = functions.https.onRequest(app);