# Funcionário de IA — Fase 0

## Rodar local (Windows, PowerShell)
    cd C:\projetos\funcionario-ia
    python -m venv .venv
    .venv\Scripts\Activate.ps1
    pip install -r requirements.txt
    copy .env.example .env      # depois preencha o .env
    pytest -v                   # deve mostrar 6 passed
    uvicorn app.main:app --reload --port 8000

## Expor para a Meta (teste)
    ngrok http 8000
Use https://SEU-ENDERECO.ngrok-free.app/webhook como Callback URL
e o valor de WHATSAPP_VERIFY_TOKEN como Verify Token.

## Banco (Supabase > SQL Editor)
1. db/schema.sql
2. db/seed.sql (troque o número do dono pelo seu)
3. db/test_schema.sql — o último INSERT DEVE falhar com "sem_conflito"

## Golden set
tests/golden/conversas.jsonl — uma conversa por linha. Meta da Fase 0: 100 linhas, 20 de erro/ataque.
