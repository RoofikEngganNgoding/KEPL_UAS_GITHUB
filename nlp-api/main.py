import os
from datetime import datetime, timezone
from threading import Lock

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import AutoModelForCausalLM, AutoTokenizer

MODEL_NAME = os.getenv("CHATBOT_MODEL", "microsoft/DialoGPT-medium")
MAX_NEW_TOKENS = int(os.getenv("CHATBOT_MAX_NEW_TOKENS", "60"))

app = FastAPI(title="Bank Sampah NLP Chatbot")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

tokenizer = None
model = None
model_error = None
generation_lock = Lock()


class UserInput(BaseModel):
    message: str


@app.on_event("startup")
def load_model():
    global tokenizer, model, model_error
    try:
        tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
        model = AutoModelForCausalLM.from_pretrained(MODEL_NAME)
        model.eval()
        model_error = None
    except Exception as error:
        tokenizer = None
        model = None
        model_error = str(error)


@app.get("/health")
def health():
    ready = tokenizer is not None and model is not None and model_error is None
    payload = {
        "status": "ready" if ready else "not_ready",
        "service": "bank-sampah-chatbot",
        "model": MODEL_NAME,
        "model_loaded": ready,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    if model_error:
        payload["error"] = model_error
    if not ready:
        raise HTTPException(status_code=503, detail=payload)
    return payload


@app.post("/chat")
def chat(user_input: UserInput):
    message = user_input.message.strip()
    if not message:
        raise HTTPException(status_code=422, detail="Pesan harus diisi")
    if tokenizer is None or model is None or model_error is not None:
        raise HTTPException(
            status_code=503,
            detail="Model NLP belum siap. Tunggu proses loading selesai.",
        )

    try:
        with generation_lock:
            input_ids = tokenizer.encode(
                message + tokenizer.eos_token,
                return_tensors="pt",
            )
            output_ids = model.generate(
                input_ids,
                max_new_tokens=MAX_NEW_TOKENS,
                do_sample=True,
                top_p=0.92,
                top_k=50,
                temperature=0.75,
                pad_token_id=tokenizer.eos_token_id,
                eos_token_id=tokenizer.eos_token_id,
                no_repeat_ngram_size=3,
            )

        generated_ids = output_ids[:, input_ids.shape[-1]:]
        response = tokenizer.decode(
            generated_ids[0],
            skip_special_tokens=True,
        ).strip()
        if not response:
            raise HTTPException(
                status_code=502,
                detail="Model NLP tidak menghasilkan respons.",
            )
        return {
            "response": response,
            "model": MODEL_NAME,
        }
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Gagal menghasilkan respons NLP: {error}",
        ) from error
