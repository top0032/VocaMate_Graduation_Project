const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const textToSpeech = require('@google-cloud/text-to-speech');

admin.initializeApp();

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// API 키 직접 입력 (사용자님의 키 유지)
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

// TTS 클라이언트 초기화
const ttsClient = new textToSpeech.TextToSpeechClient();

// ---------------------------------------------------------
// 1. Gemini 예문 생성 API (gemini-2.5-flash 모델 유지)
// ---------------------------------------------------------
app.post('/generate-example', async (req, res) => {
  if (!GEMINI_API_KEY) return res.status(500).json({ error: 'API Key missing' });

  const { word, meaning } = req.body;
  if (!word || !meaning) return res.status(400).json({ error: 'Missing data' });

  try {
    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
    
    // 💡 요청하신대로 'gemini-2.5-flash' 모델 사용 (수정 금지)
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
    
    const prompt = `
    Task: Create 3 example sentences for the word "${word}" (meaning: "${meaning}").
    Strict Output Format Rules:
    1. Do NOT add any introductory text or markdown like "**".
    2. Provide exactly 3 sets (Beginner, Intermediate, Advanced).
    3. The format must be exactly as follows with line breaks:

    (Beginner English Sentence)
    (Korean Translation)

    (Intermediate English Sentence)
    (Korean Translation)

    (Advanced English Sentence)
    (Korean Translation)
    `;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    res.json({ generatedText: text });

  } catch (error) {
    console.error('Gemini Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ---------------------------------------------------------
// 2. TTS API (줄 단위 언어 감지 및 병합)
// ---------------------------------------------------------
app.post('/generate-speech', async (req, res) => {
  const { text, speed } = req.body;
  if (!text) return res.status(400).json({ error: 'Missing text' });

  // 💡 1. 텍스트를 줄바꿈(\n) 기준으로 분리하여 배열로 만듭니다.
  // 이렇게 하면 영어 문장과 한글 해석이 각각 별도의 줄로 나뉩니다.
  const lines = text.split('\n').filter(line => line.trim() !== '');
  
  // 오디오 조각들을 담을 배열
  const audioBuffers = [];

  try {
    // 💡 2. 각 줄마다 언어를 감지하고 알맞은 목소리로 TTS 생성
    for (const line of lines) {
        // 한글 포함 여부 확인
        const hasKorean = /[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]/.test(line);
        
        // 언어별 최적의 목소리 설정
        // 영어: en-US-Studio-M (가장 자연스러운 원어민 남성 발음)
        // 한국어: ko-KR-Neural2-C (자연스러운 한국인 남성 발음)
        const languageCode = hasKorean ? 'ko-KR' : 'en-US';
        const voiceName = hasKorean ? 'ko-KR-Neural2-C' : 'en-US-Studio-M';

        const request = {
            input: { text: line },
            voice: { languageCode: languageCode, name: voiceName },
            // 영어는 속도 조절 반영, 한국어는 기본 속도(1.0) 유지 등 미세 조정 가능
            // 여기서는 입력받은 속도를 일괄 적용합니다.
            audioConfig: { audioEncoding: 'MP3', speakingRate: speed || 1.0 },
        };

        // Google Cloud TTS 호출
        const [response] = await ttsClient.synthesizeSpeech(request);
        
        // 생성된 오디오 데이터를 배열에 추가
        if (response.audioContent) {
            audioBuffers.push(response.audioContent);
        }
    }

    // 💡 3. 생성된 모든 오디오 조각(Buffer)을 하나로 이어 붙입니다.
    const finalAudio = Buffer.concat(audioBuffers);

    // 합쳐진 오디오 데이터를 Base64 문자열로 변환하여 앱으로 전송
    res.json({ audioContent: finalAudio.toString('base64') });

  } catch (error) {
    console.error('TTS Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// v2 문법으로 내보내기 (타임아웃 300초, 메모리 1GiB)
exports.api = onRequest({ timeoutSeconds: 300, memory: "1GiB" }, app);