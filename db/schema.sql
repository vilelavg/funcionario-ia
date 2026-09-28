-- Funcionário de IA — esquema v0 (Fase 0)
-- Rodar no SQL Editor do Supabase, nesta ordem: schema.sql, depois seed.sql

CREATE EXTENSION IF NOT EXISTS btree_gist;  -- necessário para a trava de conflito de agenda

CREATE TABLE empresas (
    id              BIGSERIAL PRIMARY KEY,
    nome            TEXT NOT NULL,
    whatsapp_dono   TEXT NOT NULL,                  -- só este número acessa o painel do dono
    fuso_horario    TEXT NOT NULL DEFAULT 'America/Sao_Paulo',
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE servicos (
    id              BIGSERIAL PRIMARY KEY,
    empresa_id      BIGINT NOT NULL REFERENCES empresas(id),
    nome            TEXT NOT NULL,
    preco_centavos  INTEGER NOT NULL CHECK (preco_centavos > 0),  -- dinheiro sempre em centavos
    duracao_min     INTEGER NOT NULL CHECK (duracao_min BETWEEN 5 AND 480),
    ativo           BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE profissionais (
    id              BIGSERIAL PRIMARY KEY,
    empresa_id      BIGINT NOT NULL REFERENCES empresas(id),
    nome            TEXT NOT NULL,
    ativo           BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE clientes (
    id              BIGSERIAL PRIMARY KEY,
    empresa_id      BIGINT NOT NULL REFERENCES empresas(id),
    whatsapp        TEXT NOT NULL,
    nome            TEXT,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now(),
    anonimizado_em  TIMESTAMPTZ,                    -- LGPD: preenchido pela rotina de retenção
    UNIQUE (empresa_id, whatsapp)
);

-- LGPD + política do WhatsApp: todo opt-in e opt-out fica registrado com data
CREATE TABLE consentimentos (
    id              BIGSERIAL PRIMARY KEY,
    cliente_id      BIGINT NOT NULL REFERENCES clientes(id),
    tipo            TEXT NOT NULL CHECK (tipo IN ('privacidade', 'lembretes', 'marketing')),
    concedido       BOOLEAN NOT NULL,
    registrado_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE conversas (
    id              BIGSERIAL PRIMARY KEY,
    cliente_id      BIGINT NOT NULL REFERENCES clientes(id),
    status          TEXT NOT NULL DEFAULT 'bot' CHECK (status IN ('bot', 'humano', 'encerrada')),
    resumo          TEXT,                           -- usado na transferência para humano
    iniciada_em     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE mensagens (
    id              BIGSERIAL PRIMARY KEY,
    conversa_id     BIGINT NOT NULL REFERENCES conversas(id),
    wa_message_id   TEXT UNIQUE,                    -- trava contra mensagem duplicada do webhook
    direcao         TEXT NOT NULL CHECK (direcao IN ('entrada', 'saida')),
    tipo            TEXT NOT NULL,
    conteudo        TEXT,
    intencao        TEXT,
    modelo_ia       TEXT,
    tokens          INTEGER,
    latencia_ms     INTEGER,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE agendamentos (
    id              BIGSERIAL PRIMARY KEY,
    empresa_id      BIGINT NOT NULL REFERENCES empresas(id),
    cliente_id      BIGINT NOT NULL REFERENCES clientes(id),
    servico_id      BIGINT NOT NULL REFERENCES servicos(id),
    profissional_id BIGINT NOT NULL REFERENCES profissionais(id),
    periodo         TSTZRANGE NOT NULL,
    status          TEXT NOT NULL DEFAULT 'confirmado'
                    CHECK (status IN ('confirmado', 'cancelado', 'concluido', 'faltou')),
    google_event_id TEXT,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- TRAVA NO BANCO: o mesmo profissional não pode ter dois horários sobrepostos
    CONSTRAINT sem_conflito EXCLUDE USING gist (
        profissional_id WITH =, periodo WITH &&
    ) WHERE (status <> 'cancelado')
);

CREATE TABLE cobrancas (
    id                  BIGSERIAL PRIMARY KEY,
    agendamento_id      BIGINT NOT NULL REFERENCES agendamentos(id),
    valor_centavos      INTEGER NOT NULL CHECK (valor_centavos > 0),
    chave_idempotencia  TEXT NOT NULL UNIQUE,       -- trava contra cobrança duplicada
    provedor_id         TEXT UNIQUE,
    status              TEXT NOT NULL DEFAULT 'pendente'
                        CHECK (status IN ('pendente', 'paga', 'expirada', 'cancelada')),
    pago_em             TIMESTAMPTZ,
    criado_em           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE notas_fiscais (
    id              BIGSERIAL PRIMARY KEY,
    cobranca_id     BIGINT NOT NULL UNIQUE REFERENCES cobrancas(id),  -- no máximo 1 nota por cobrança
    status          TEXT NOT NULL DEFAULT 'aguardando_aprovacao'
                    CHECK (status IN ('aguardando_aprovacao', 'emitindo', 'emitida', 'erro', 'cancelada')),
    numero          TEXT,
    erro            TEXT,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auditoria: toda ação sensível passa por aqui, aprovada ou bloqueada
CREATE TABLE log_acoes (
    id              BIGSERIAL PRIMARY KEY,
    empresa_id      BIGINT NOT NULL REFERENCES empresas(id),
    conversa_id     BIGINT REFERENCES conversas(id),
    acao            TEXT NOT NULL,
    parametros      JSONB NOT NULL DEFAULT '{}',
    resultado       TEXT NOT NULL CHECK (resultado IN ('executada', 'bloqueada_trava', 'aguardando_aprovacao', 'erro')),
    motivo          TEXT,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_mensagens_conversa ON mensagens (conversa_id, criado_em);
CREATE INDEX idx_agendamentos_empresa ON agendamentos (empresa_id, lower(periodo));
CREATE INDEX idx_log_empresa ON log_acoes (empresa_id, criado_em);
