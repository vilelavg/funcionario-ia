-- Funcionário de IA — migração 002: ajustes após revisão contra o fluxo da barbearia
-- Rodar no SQL Editor do Supabase DEPOIS do schema.sql e do seed.sql

-- Regras do negócio configuráveis por empresa (valores = sugestões do documento de fluxo)
ALTER TABLE empresas
    ADD COLUMN antecedencia_min_minutos INTEGER NOT NULL DEFAULT 120 CHECK (antecedencia_min_minutos >= 0),
    ADD COLUMN agenda_max_dias          INTEGER NOT NULL DEFAULT 30  CHECK (agenda_max_dias BETWEEN 1 AND 365),
    ADD COLUMN cancelamento_min_minutos INTEGER NOT NULL DEFAULT 120 CHECK (cancelamento_min_minutos >= 0),
    ADD COLUMN desconto_max_pct         INTEGER NOT NULL DEFAULT 15  CHECK (desconto_max_pct BETWEEN 0 AND 50),
    ADD COLUMN envios_ativos_dia_max    INTEGER NOT NULL DEFAULT 50  CHECK (envios_ativos_dia_max BETWEEN 0 AND 1000),
    ADD COLUMN retencao_dias            INTEGER NOT NULL DEFAULT 365 CHECK (retencao_dias >= 30),
    ADD COLUMN aprovar_nfse             BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN bot_pausado              BOOLEAN NOT NULL DEFAULT false,   -- botão de pausa geral (F13)
    ADD COLUMN tom_de_voz               TEXT;

-- F02/F03: horário de funcionamento (0 = domingo ... 6 = sábado)
CREATE TABLE horarios_funcionamento (
    id          BIGSERIAL PRIMARY KEY,
    empresa_id  BIGINT NOT NULL REFERENCES empresas(id),
    dia_semana  SMALLINT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
    abre        TIME NOT NULL,
    fecha       TIME NOT NULL,
    CHECK (abre < fecha),
    UNIQUE (empresa_id, dia_semana, abre)
);

-- F03/F13: folgas, almoço, feriados (profissional_id nulo = a barbearia inteira)
CREATE TABLE bloqueios_agenda (
    id              BIGSERIAL PRIMARY KEY,
    empresa_id      BIGINT NOT NULL REFERENCES empresas(id),
    profissional_id BIGINT REFERENCES profissionais(id),
    periodo         TSTZRANGE NOT NULL,
    motivo          TEXT,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- F03: qual profissional faz qual serviço
CREATE TABLE profissional_servicos (
    profissional_id BIGINT NOT NULL REFERENCES profissionais(id),
    servico_id      BIGINT NOT NULL REFERENCES servicos(id),
    PRIMARY KEY (profissional_id, servico_id)
);

-- F08/F09/F14: toda mensagem ativa (lembrete, follow-up, reativação, pós-venda)
CREATE TABLE envios_ativos (
    id              BIGSERIAL PRIMARY KEY,
    empresa_id      BIGINT NOT NULL REFERENCES empresas(id),
    cliente_id      BIGINT NOT NULL REFERENCES clientes(id),
    tipo            TEXT NOT NULL CHECK (tipo IN ('lembrete_vespera', 'lembrete_2h', 'follow_up', 'reativacao', 'pos_venda')),
    referencia      TEXT NOT NULL,                  -- ex.: 'agendamento-12', 'conversa-40', 'reativacao-2026-10'
    tentativa       SMALLINT NOT NULL DEFAULT 1 CHECK (tentativa BETWEEN 1 AND 2),  -- TRAVA: no máximo 2
    status          TEXT NOT NULL DEFAULT 'agendado' CHECK (status IN ('agendado', 'enviado', 'cancelado', 'falhou')),
    agendado_para   TIMESTAMPTZ NOT NULL,
    enviado_em      TIMESTAMPTZ,
    UNIQUE (cliente_id, tipo, referencia, tentativa) -- TRAVA: nunca o mesmo envio duas vezes
);
CREATE INDEX idx_envios_fila ON envios_ativos (status, agendado_para);

-- F12: pedidos do titular (LGPD)
CREATE TABLE pedidos_titular (
    id              BIGSERIAL PRIMARY KEY,
    cliente_id      BIGINT NOT NULL REFERENCES clientes(id),
    tipo            TEXT NOT NULL CHECK (tipo IN ('acesso', 'correcao', 'exclusao')),
    status          TEXT NOT NULL DEFAULT 'recebido' CHECK (status IN ('recebido', 'em_analise', 'concluido', 'recusado')),
    recebido_em     TIMESTAMPTZ NOT NULL DEFAULT now(),
    concluido_em    TIMESTAMPTZ
);

-- F13: promoções que o bot pode oferecer
CREATE TABLE promocoes (
    id              BIGSERIAL PRIMARY KEY,
    empresa_id      BIGINT NOT NULL REFERENCES empresas(id),
    servico_id      BIGINT REFERENCES servicos(id),  -- nulo = vale para todos
    descricao       TEXT NOT NULL,
    desconto_pct    INTEGER NOT NULL CHECK (desconto_pct BETWEEN 1 AND 50),
    valida_ate      DATE NOT NULL,
    ativa           BOOLEAN NOT NULL DEFAULT true
);

-- F14: pesquisa de satisfação
CREATE TABLE avaliacoes (
    id              BIGSERIAL PRIMARY KEY,
    agendamento_id  BIGINT NOT NULL UNIQUE REFERENCES agendamentos(id),  -- uma avaliação por atendimento
    nota            SMALLINT NOT NULL CHECK (nota BETWEEN 1 AND 5),
    comentario      TEXT,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Dados da demo: funcionamento terça a sábado, 9h às 20h; os dois profissionais fazem tudo
INSERT INTO horarios_funcionamento (empresa_id, dia_semana, abre, fecha)
SELECT 1, d, '09:00', '20:00' FROM generate_series(2, 6) AS d;

INSERT INTO profissional_servicos (profissional_id, servico_id)
SELECT p.id, s.id FROM profissionais p CROSS JOIN servicos s WHERE p.empresa_id = 1 AND s.empresa_id = 1;
