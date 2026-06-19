from fastapi import FastAPI, HTTPException 
from fastapi.middleware.cors import CORSMiddleware 
from pydantic import BaseModel 
from transformers import pipeline 
from fuzzywuzzy import fuzz 
import re 
 
app = FastAPI() 
 
# Configure CORS 
app.add_middleware( 
    CORSMiddleware, 
    allow_origins=["*"],  # Adjust as needed #http://127.0.0.1:8000/chat
    allow_credentials=True, 
    allow_methods=["*"], 
    allow_headers=["*"], 
) 
 
chatbot_pipeline = pipeline("text-generation", model="microsoft/DialoGPT-medium") 
 
FAQ_DATA = { 
    "Apa itu Bank Sampah Sungailiat?": "Bank Sampah Sungailiat adalah program pengelolaan sampah berbasis masyarakat di Sungailiat, Bangka Belitung, yang bertujuan mengurangi sampah melalui daur ulang dan memberikan nilai ekonomis bagi nasabah.", 
    "Bagaimana cara menjadi nasabah Bank Sampah Sungailiat?": "Anda dapat mendaftar sebagai nasabah dengan mengunjungi kantor Bank Sampah Sungailiat di Sungailiat, membawa KTP, dan mengisi formulir pendaftaran. Setelah itu, Anda bisa menyetor sampah yang sudah dipilah.", 
    "Apa saja layanan Bank Sampah Sungailiat?": "Layanan Bank Sampah Sungailiat meliputi pengumpulan sampah terpilah (plastik, kertas, logam), penimbangan sampah, pencatatan tabungan sampah, serta edukasi tentang pengelolaan sampah dan daur ulang." ,
    "Siapa yang membuat sistem Bank Sampah Sungailiat ini?" : "Sistem Bank Sampah Sungailiat ini dikembangkan oleh tim yang terdiri dari Roofik Aditya, Daveo Dava, dan Juliarti Safitri.",
    "Siapa pengembang sistem ini?": "Sistem ini dikembangkan oleh Roofik Aditya, Daveo Dava, dan Juliarti Safitri.",
    "Siapa saja tim pembuat sistem?": "Tim pembuat sistem ini adalah Roofik Aditya, Daveo Dava, dan Juliarti Safitri.",
} 
 
# Keyword mappings for common terms 
KEYWORD_SYNONYMS = { 
    "cara": ["bagaimana", "gimana", "cara"], 
    "akses": ["mengakses", "akses", "buka", "dapatkan"], 
    "data": ["data", "informasi", "sampah"] 
} 
 
class UserInput(BaseModel): 
    message: str 
 
def preprocess_input(message: str) -> str: 
    """Normalize user input: lowercase, remove extra spaces, and handle basic 
synonyms.""" 
    message = re.sub(r'\s+', ' ', message.strip().lower()) 
    # Replace synonyms with canonical terms 
    for canonical, synonyms in KEYWORD_SYNONYMS.items(): 
        for synonym in synonyms: 
            message = message.replace(synonym, canonical) 
    return message 
 
def find_best_faq_match(user_message: str) -> tuple[str, int]: 
    """Find the best FAQ match using multiple fuzzy matching strategies.""" 
    best_match = None 
    highest_score = 0 
 
    for question in FAQ_DATA: 
        # Preprocess FAQ question 
        processed_question = preprocess_input(question) 
        processed_message = preprocess_input(user_message) 
 
        # Use multiple fuzzy matching strategies 
        partial_score = fuzz.partial_ratio(processed_message, processed_question) 
        token_sort_score = fuzz.token_sort_ratio(processed_message, 
processed_question) 
        ratio_score = fuzz.ratio(processed_message, processed_question) 
 
        # Combine scores (weighted average for better accuracy) 
        combined_score = (partial_score * 0.5 + token_sort_score * 0.3 + 
ratio_score * 0.2) 
 
        # Lowered threshold to allow looser matches 
        if combined_score > 70 and combined_score > highest_score:  # Lowered from 80 to 70 
            best_match = question 
            highest_score = combined_score 
 
        # Keyword-based matching as a fallback 
        if not best_match: 
            user_words = set(processed_message.split()) 
            question_words = set(processed_question.split()) 
            common_keywords = user_words.intersection(question_words) 
            if len(common_keywords) >= 2:  # At least 2 common keywords 
                best_match = question 
                highest_score = 75  # Arbitrary score for keyword match 
 
    return best_match, highest_score 
 
@app.post("/chat") 
async def chat(user_input: UserInput): 
    user_message = user_input.message.strip() 
 
    # Find the best FAQ match 
    best_match, score = find_best_faq_match(user_message) 
    if best_match and score > 70: 
        return {"response": FAQ_DATA[best_match]} 
 
    # Fallback to NLP 
    try: 
        response = chatbot_pipeline( 
            user_message, 
            max_length=150, 
            num_return_sequences=1, 
            do_sample=True, 
            top_p=0.9, 
            temperature=0.7, 
            pad_token_id=chatbot_pipeline.tokenizer.eos_token_id 
        )[0]["generated_text"] 
         
        # Remove input from output if present 
        if response.startswith(user_message): 
            response = response[len(user_message):].strip() 
         
        return {"response": response or "Maaf, saya tidak bisa menghasilkan respons yang sesuai."} 
    except Exception as e: 
        raise HTTPException(status_code=500, detail=f"Error processing request: {str(e)}") 
 
@app.get("/faq") 
async def faq(): 
    return FAQ_DATA

@app.get("/")
async def root():
    return {
        "message": "API Chatbot Bank Sampah Sungailiat aktif",
        "docs": "http://127.0.0.1:8000/docs"
    }