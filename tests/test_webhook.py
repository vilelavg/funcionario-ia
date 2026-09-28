import hashlib
import hmac
import json

import pytest
from fastapi.testclient import TestClient

import app.main as m


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(m, "VERIFY_TOKEN", "segredo-teste")
    monkeypatch.setattr(m, "APP_SECRET", "app-secret-teste")
    m.mensagens_processadas.clear()
    return TestClient(m.app)


def assinar(corpo: bytes) -> str:
    return "sha256=" + hmac.new(b"app-secret-teste", corpo, hashlib.sha256).hexdigest()


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_verificacao_token_correto(client):
    r = client.get("/webhook", params={"hub.mode": "subscribe", "hub.verify_token": "segredo-teste", "hub.challenge": "123"})
    assert r.status_code == 200 and r.text == "123"


def test_verificacao_token_errado(client):
    r = client.get("/webhook", params={"hub.mode": "subscribe", "hub.verify_token": "errado", "hub.challenge": "123"})
    assert r.status_code == 403


def test_rejeita_sem_assinatura(client):
    assert client.post("/webhook", content=b"{}").status_code == 401


def test_rejeita_assinatura_falsa(client):
    r = client.post("/webhook", content=b"{}", headers={"X-Hub-Signature-256": "sha256=falsa"})
    assert r.status_code == 401


def test_mensagem_duplicada_responde_uma_vez(client, monkeypatch):
    enviados = []

    async def falso_responder(para, texto):
        enviados.append(para)

    monkeypatch.setattr(m, "responder", falso_responder)
    evento = {"entry": [{"changes": [{"value": {"messages": [
        {"id": "wamid.1", "from": "5511999999999", "type": "text", "text": {"body": "oi"}}]}}]}]}
    corpo = json.dumps(evento).encode()
    for _ in range(2):
        r = client.post("/webhook", content=corpo, headers={"X-Hub-Signature-256": assinar(corpo), "Content-Type": "application/json"})
        assert r.status_code == 200
    assert enviados == ["5511999999999"]
