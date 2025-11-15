const functions = require('firebase-functions');
const express = require('express');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const cors = require('cors');

// 1. express 앱 초기화
const app = express();

// 2. CORS 및 JSON 파서 사용
//    (중요: Functions에서 CORS는 필수입니다)
app.use(cors({ origin: true })); 
app.use(express.json());

// 3. API 키 가져오기 (dotenv 대신 functions.config() 사용)
//    보안을 위해 functions.config()에서 키를 불러옵니다.
const GEMINI_API_KEY = functions.config().gemini.key;

// API 키가 Firebase 환경 변수에 설정되지 않았다면 오류를 발생시킵니다.
if (!GEMINI_API_KEY) {
  console.error('GEMINI_API_KEY is not set in Firebase config.');
  // 참고: 여기서는 process.exit(1)을 사용하지 않습니다.
}

const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

// 4. 학생분의 API 라우트 (기존 코드와 100% 동일)
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

// 5. (가장 중요) app.listen() 대신
//    Express 앱을 'api'라는 이름의 HTTPS 함수로 export 합니다.
exports.api = functions.https.onRequest(app);