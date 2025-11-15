// 1. 필요한 모듈만 require (초기화는 나중에)
const functions = require('firebase-functions');
const express = require('express');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const cors = require('cors');
require('dotenv').config(); // .env 파일을 읽기 위해 이 줄을 추가합니다.

const app = express();
app.use(cors({ origin: true })); 
app.use(express.json());

// 4. API 라우트
app.post('/generate-example', async (req, res) => {
  
  // 💡 모든 초기화 코드를 'try...catch' 블록 안으로 이동시켰습니다.
  try {
    // 1. API 키를 함수 내부에서 불러옵니다.
    const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

    // 2. API 키가 있는지 확인합니다.
    if (!GEMINI_API_KEY) {
      console.error('GEMINI_API_KEY is not set in .env file.');
      // JSON 오류를 보냅니다.
      return res.status(500).json({ error: 'Server configuration error: API Key is missing.' });
    }

    // 3. (가장 중요) genAI 인스턴스를 'try' 블록 안에서 생성합니다.
    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY); 

    // 4. 요청 본문(word, meaning)을 확인합니다.
    const { word, meaning } = req.body;
    if (!word || !meaning) {
      return res.status(400).json({ error: 'Word and meaning are required.' });
    }

    // 5. Gemini API를 호출합니다.
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
    const prompt = `Generate 3 example sentences using the English word "${word}" with its Korean meaning "${meaning}". Provide the output in Korean. Each example sentence be on a new line, followed by its Korean translation on the next line. For example:
English sentence 1.
한국어 번역 1.
English sentence 2.
한국어 번역 2.
English sentence 3.
한국어 번역 3.`;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    // 6. 성공 시 JSON 응답을 보냅니다.
    res.json({ generatedText: text });

  } catch (error) {
    // 7. (중요) 이제 API 키 오류, Gemini 호출 오류 등 '모든' 오류가 여기서 잡힙니다.
    console.error('Gemini API call or init failed:', error);
    // JSON 오류를 보냅니다.
    res.status(500).json({ error: 'Failed to process request on server.', details: error.message });
  }
});

// 5. Express 앱을 'api'라는 이름으로 export 합니다.
exports.api = functions.https.onRequest(app);