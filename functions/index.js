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

// 💡 전역 변수에서는 초기화하지 않음 (배포 실패 방지)
// const ttsClient = new textToSpeech.TextToSpeechClient(); // <- 이걸 함수 안으로 이동하거나 lazy loading 할 수 있지만, 일단 둡니다.

// 1. Gemini 예문 생성 API
app.post('/generate-example', async (req, res) => {
  // 💡 요청이 들어왔을 때 API 키를 확인합니다. (배포 시 터지는 것 방지)
  const GEMINI_API_KEY = process.env.GEMINI_API_KEY || functions.config().gemini?.key;

  if (!GEMINI_API_KEY) {
    console.error('ERROR: GEMINI_API_KEY is missing.');
    return res.status(500).json({ error: 'Server configuration error: API Key missing.' });
  }

  const { word, meaning } = req.body;
  if (!word || !meaning) return res.status(400).json({ error: 'Missing data' });

  try {
    // 💡 키가 있을 때 인스턴스 생성
    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-pro' });
    
    const prompt = `Generate 3 example sentences using "${word}" (${meaning}). Output in Korean. Format: English\nKorean...`;
    
    const result = await model.generateContent(prompt);
    const response = await result.response;
    res.json({ generatedText: response.text() });
  } catch (error) {
    console.error('Gemini Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// 2. 고품질 TTS 생성 API
app.post('/generate-speech', async (req, res) => {
  const { text } = req.body;
  if (!text) return res.status(400).json({ error: 'Missing text' });

  // TTS 클라이언트 생성 (호출 시점에 생성하거나 전역에 둬도 됨)
  const ttsClient = new textToSpeech.TextToSpeechClient();

  const request = {
    input: { text: text },
    voice: { languageCode: 'en-US', name: 'en-US-Neural2-D' },
    audioConfig: { audioEncoding: 'MP3' },
  };

  try {
    const [response] = await ttsClient.synthesizeSpeech(request);
    res.json({ audioContent: response.audioContent.toString('base64') });
  } catch (error) {
    console.error('TTS Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// HTTPS 요청 처리
exports.api = functions.https.onRequest(app);