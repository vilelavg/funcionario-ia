"""
Funcionário de IA — Fase 0
Webhook mínimo do WhatsApp Cloud API: verifica, valida assinatura,
ignora duplicadas e responde para confirmar envio e recebimento.
"""
import hashlib
import hmac
import logging
import os

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, Response

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("funcionario-ia")

VERIFY_TOKEN = os.getenv("WHATSAPP_VERIFY_TOKEN", "")
APP_SECRET = os.getenv("WHATSAPP_APP_SECRET", "")
TOKEN = os.getenv("WHATSAPP_TOKEN", "")
PHONE_ID = os.getenv("WHATSAPP_PHONE_NUMBER_ID", "")
GRAPH_VERSION = os.getenv("GRAPH_API_VERSION", "v26.0")
MODO_SIMULACAO = os.getenv("MODO_SIMULACAO", "0") == "1"

app = FastAPI(title="Funcionário de IA")
mensagens_processadas: set[str] = set()  # Fase 1 troca isto por tabela no banco


def assinatura_valida(corpo: bytes, cabecalho: str | None) -> bool:
    """Confere o X-Hub-Signature-256 enviado pela Meta."""
    if not APP_SECRET or not cabecalho or not cabecalho.startswith("sha256="):
        return False
    esperado = hmac.new(APP_SECRET.encode(), corpo, hashlib.sha256).hexdigest()
    return hmac.compare_digest(esperado, cabecalho.removeprefix("sha256="))


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/webhook")
def verificar(request: Request) -> Response:
    p = request.query_params
    log.info("[1/1] Meta pediu verificação do webhook")
    if p.get("hub.mode") == "subscribe" and VERIFY_TOKEN and p.get("hub.verify_token") == VERIFY_TOKEN:
        log.info("      ✔ token confere, webhook verificado")
        return Response(content=p.get("hub.challenge", ""), media_type="text/plain")
    log.warning("      ✘ token não confere")
    raise HTTPException(status_code=403, detail="token inválido")


@app.post("/webhook")
async def receber(request: Request) -> dict:
    corpo = await request.body()
    log.info("[1/4] Evento recebido")
    if not assinatura_valida(corpo, request.headers.get("X-Hub-Signature-256")):
        log.warning("      ✘ assinatura inválida, evento descartado")
        raise HTTPException(status_code=401, detail="assinatura inválida")
    log.info("[2/4] ✔ Assinatura válida")

    dados = await request.json()
    for entrada in dados.get("entry", []):
        for mudanca in entrada.get("changes", []):
            for msg in mudanca.get("value", {}).get("messages", []):
                msg_id, remetente = msg.get("id"), msg.get("from")
                if msg_id in mensagens_processadas:
                    log.info("[3/4] ↺ Mensagem %s repetida, ignorada", msg_id)
                    continue
                mensagens_processadas.add(msg_id)
                texto = msg.get("text", {}).get("body", f"<{msg.get('type')}>")
                log.info("[3/4] ✉ De %s: %s", remetente, texto)
                await responder(remetente, "Recebi sua mensagem! (teste da Fase 0)")
    return {"status": "ok"}


async def responder(para: str, texto: str) -> None:
    if MODO_SIMULACAO:
        log.info("[4/4] ⚙ (simulação) Resposta para %s: %s", para, texto)
        return
    url = f"https://graph.facebook.com/{GRAPH_VERSION}/{PHONE_ID}/messages"
    payload = {"messaging_product": "whatsapp", "to": para, "type": "text", "text": {"body": texto}}
    async with httpx.AsyncClient(timeout=10) as cliente:
        r = await cliente.post(url, json=payload, headers={"Authorization": f"Bearer {TOKEN}"})
    if r.is_success:
        log.info("[4/4] ✔ Resposta enviada")
    else:
        log.error("[4/4] ✘ Falha ao enviar (%s): %s", r.status_code, r.text[:300])
