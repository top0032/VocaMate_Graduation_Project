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

// API 키 직접 입력
const GEMINI_API_KEY = "AIzaSyC21YLnGVDtUiJ6ymMocPpX_yAifjlija4";

// TTS 클라이언트 초기화
const ttsClient = new textToSpeech.TextToSpeechClient();

// ---------------------------------------------------------
// 1. Gemini 예문 생성 API (gemini-2.5-flash 사용)
// ---------------------------------------------------------
app.post('/generate-example', async (req, res) => {
  if (!GEMINI_API_KEY) return res.status(500).json({ error: 'API Key missing' });

  const { word, meaning } = req.body;
  if (!word || !meaning) return res.status(400).json({ error: 'Missing data' });

  try {
    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
    
    // 요청하신 'gemini-2.5-flash' 모델 유지
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
    
    // 💡 [프롬프트 수정] 라벨(1. 초급 등) 제거하고 문장만 출력하도록 강제
    const prompt = `
    Task: Create 3 example sentences for the word "${word}" (meaning: "${meaning}").
    The sentences must be in increasing order of difficulty: Beginner -> Intermediate -> Advanced.
    
    Strict Output Format Rules:
    1. Do NOT add any introductory text, markdown, or numbering (like "1.", "Beginner:", "초급:").
    2. Do NOT add labels. Just provide the sentences.
    3. The format must be exactly as follows (English line, then Korean line):

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
// 2. TTS API (영어/한국어 자동 분리 및 고품질 보이스 적용)
// ---------------------------------------------------------
app.post('/generate-speech', async (req, res) => {
  const { text, speed } = req.body;
  if (!text) return res.status(400).json({ error: 'Missing text' });

  // 💡 텍스트를 줄 단위로 분리 (빈 줄 제거)
  const lines = text.split('\n').filter(line => line.trim() !== '');
  
  // 생성된 오디오 버퍼들을 저장할 배열
  const audioBuffers = [];

  try {
    // 각 줄별로 언어를 감지하고 TTS를 생성
    for (const line of lines) {
        // 한글 포함 여부 확인
        const hasKorean = /[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]/.test(line);
        
        // 💡 언어에 따라 완벽한 목소리 선택
        // 영어 문장: Studio-M (원어민 성우, 자연스러운 발음)
        // 한국어 문장: Neural2-C (자연스러운 남성 한국어)
        const languageCode = hasKorean ? 'ko-KR' : 'en-US';
        const voiceName = hasKorean ? 'ko-KR-Neural2-C' : 'en-US-Studio-M';

        const request = {
            input: { text: line },
            voice: { languageCode: languageCode, name: voiceName },
            // 영어는 약간 빠르게, 한국어는 보통 속도로 (선택 사항, 여기선 동일 속도 적용)
            audioConfig: { audioEncoding: 'MP3', speakingRate: speed || 1.0 },
        };

        // Google Cloud TTS 호출
        const [response] = await ttsClient.synthesizeSpeech(request);
        
        // 결과 오디오 데이터를 배열에 추가
        if (response.audioContent) {
            audioBuffers.push(response.audioContent);
        }
    }

    // 💡 모든 오디오 조각을 하나로 합치기 (영어 문장 + 한국어 해석 ...)
    const finalAudio = Buffer.concat(audioBuffers);

    // 합쳐진 오디오 반환
    res.json({ audioContent: finalAudio.toString('base64') });

  } catch (error) {
    console.error('TTS Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// v2 문법으로 내보내기
exports.api = onRequest({ timeoutSeconds: 300, memory: "1GiB" }, app);