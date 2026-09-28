"""
Simulador de cliente — Funcionário de IA
Envia mensagens para o seu servidor local exatamente como a Meta faria,
com assinatura válida. Não usa a internet nem o WhatsApp.

Uso (com o servidor rodando em outro terminal):
    python simular.py
"""
import hashlib
import hmac
import json
import os
import time

import httpx
from dotenv import load_dotenv

load_dotenv()

URL = "http://127.0.0.1:8000/webhook"
SECRET = os.getenv("WHATSAPP_APP_SECRET", "")
NUMERO_CLIENTE = "5511900000001"  # número fictício do cliente simulado


def montar_evento(texto: str) -> dict:
    return {
        "object": "whatsapp_business_account",
        "entry": [{
            "id": "simulado",
            "changes": [{
                "field": "messages",
                "value": {
                    "messaging_product": "whatsapp",
                    "metadata": {"display_phone_number": "simulado", "phone_number_id": "simulado"},
                    "contacts": [{"wa_id": NUMERO_CLIENTE, "profile": {"name": "Cliente Simulado"}}],
                    "messages": [{
                        "from": NUMERO_CLIENTE,
                        "id": f"wamid.simulado.{time.time_ns()}",
                        "timestamp": str(int(time.time())),
                        "type": "text",
                        "text": {"body": texto},
                    }],
                },
            }],
        }],
    }


def enviar(texto: str) -> None:
    corpo = json.dumps(montar_evento(texto)).encode()
    assinatura = "sha256=" + hmac.new(SECRET.encode(), corpo, hashlib.sha256).hexdigest()
    print("  [1/2] Enviando para o servidor...")
    try:
        r = httpx.post(URL, content=corpo, timeout=30,
                       headers={"Content-Type": "application/json", "X-Hub-Signature-256": assinatura})
    except httpx.ConnectError:
        print("  [2/2] ✘ Servidor desligado. Suba o uvicorn no outro terminal.\n")
        return
    if r.status_code == 200:
        print("  [2/2] ✔ Servidor recebeu (veja a resposta no terminal do servidor)\n")
    else:
        print(f"  [2/2] ✘ Servidor respondeu {r.status_code}: {r.text}\n")


if __name__ == "__main__":
    if not SECRET:
        raise SystemExit("✘ WHATSAPP_APP_SECRET vazio no .env")
    print("Simulador de cliente — digite a mensagem e Enter. 'sair' para encerrar.\n")
    while True:
        texto = input("Cliente: ").strip()
        if texto.lower() == "sair":
            break
        if texto:
            enviar(texto)
