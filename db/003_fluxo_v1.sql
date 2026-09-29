-- Funcionário de IA — migração 003: fluxo v1.0 aprovado em 29/09/2026
-- Rodar no SQL Editor do Supabase DEPOIS de schema.sql, seed.sql e 002_ajustes_fluxo.sql

-- 1) Regras do negócio novas ou alteradas
ALTER TABLE empresas ALTER COLUMN antecedencia_min_minutos SET DEFAULT 180;
UPDATE empresas SET antecedencia_min_minutos = 180;
ALTER TABLE empresas DROP COLUMN aprovar_nfse;   -- nota agora só a pedido
ALTER TABLE empresas
    ADD COLUMN tolerancia_atraso_min          INTEGER NOT NULL DEFAULT 10  CHECK (tolerancia_atraso_min BETWEEN 0 AND 60),
    ADD COLUMN silencio_inicio                TIME    NOT NULL DEFAULT '22:00',
    ADD COLUMN silencio_fim                   TIME    NOT NULL DEFAULT '07:00',
    ADD COLUMN envios_ativos_cliente_dia_max  INTEGER NOT NULL DEFAULT 2   CHECK (envios_ativos_cliente_dia_max BETWEEN 0 AND 5),
    ADD COLUMN reativacao_padrao_dias         INTEGER NOT NULL DEFAULT 7   CHECK (reativacao_padrao_dias BETWEEN 1 AND 180),
    ADD COLUMN resumo_diario_hora             TIME    NOT NULL DEFAULT '08:00',
    ADD COLUMN link_avaliacao_google          TEXT;

-- 2) Profissionais ganham WhatsApp e papel (quem pode dar comandos)
ALTER TABLE profissionais
    ADD COLUMN whatsapp TEXT UNIQUE,
    ADD COLUMN papel    TEXT NOT NULL DEFAULT 'barbeiro' CHECK (papel IN ('dono', 'barbeiro'));

-- 3) Estado de contato: um por cliente por vez (política unificada)
ALTER TABLE clientes
    ADD COLUMN estado_contato TEXT NOT NULL DEFAULT 'nenhum' CHECK (estado_contato IN
        ('nenhum', 'lembrete', 'conversa_pendente', 'follow_up', 'pos_cancelamento_ou_falta', 'pos_atendimento', 'reativacao')),
    ADD COLUMN estado_desde   TIMESTAMPTZ;

-- 4) Planos e assinaturas
CREATE TABLE planos (
    id              BIGSERIAL PRIMARY KEY,
    empresa_id      BIGINT NOT NULL REFERENCES empresas(id),
    nome            TEXT NOT NULL,
    preco_centavos  INTEGER NOT NULL CHECK (preco_centavos > 0),
    cortes_por_mes  INTEGER NOT NULL CHECK (cortes_por_mes BETWEEN 0 AND 31),
    beneficios      TEXT,
    ativo           BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE assinaturas (
    id               BIGSERIAL PRIMARY KEY,
    cliente_id       BIGINT NOT NULL REFERENCES clientes(id),
    plano_id         BIGINT NOT NULL REFERENCES planos(id),
    inicio           DATE NOT NULL,
    valida_ate       DATE NOT NULL,
    cortes_incluidos INTEGER NOT NULL CHECK (cortes_incluidos >= 0),   -- copiado do plano na contratação
    cortes_usados    INTEGER NOT NULL DEFAULT 0,
    status           TEXT NOT NULL DEFAULT 'ativa' CHECK (status IN ('ativa', 'vencida', 'cancelada')),
    CHECK (valida_ate > inicio),
    CHECK (cortes_usados BETWEEN 0 AND cortes_incluidos)               -- TRAVA: nunca usar mais que o incluído
);
CREATE UNIQUE INDEX uma_assinatura_ativa ON assinaturas (cliente_id) WHERE status = 'ativa';  -- TRAVA

-- 5) Agendamentos: origem, confirmação, plano e falta com autor obrigatório
ALTER TABLE agendamentos
    ADD COLUMN origem                   TEXT NOT NULL DEFAULT 'whatsapp' CHECK (origem IN ('whatsapp', 'encaixe', 'dono')),
    ADD COLUMN confirmado_em            TIMESTAMPTZ,
    ADD COLUMN assinatura_id            BIGINT REFERENCES assinaturas(id),
    ADD COLUMN falta_registrada_por     BIGINT REFERENCES profissionais(id),
    ADD CONSTRAINT falta_exige_barbeiro CHECK (status <> 'faltou' OR falta_registrada_por IS NOT NULL);  -- TRAVA

-- 6) Pagamentos registrados pelo barbeiro substituem as cobranças Pix (tabelas vazias, sem perda de dados)
DROP TABLE notas_fiscais;
DROP TABLE cobrancas;

CREATE TABLE pagamentos (
    id                  BIGSERIAL PRIMARY KEY,
    empresa_id          BIGINT NOT NULL REFERENCES empresas(id),
    cliente_id          BIGINT NOT NULL REFERENCES clientes(id),
    agendamento_id      BIGINT REFERENCES agendamentos(id),
    assinatura_id       BIGINT REFERENCES assinaturas(id),
    valor_centavos      INTEGER NOT NULL CHECK (valor_centavos > 0),
    forma               TEXT NOT NULL CHECK (forma IN ('debito', 'credito', 'pix', 'dinheiro')),
    registrado_por      BIGINT NOT NULL REFERENCES profissionais(id),
    canal               TEXT NOT NULL CHECK (canal IN ('texto', 'voz')),
    chave_idempotencia  TEXT NOT NULL UNIQUE,                                    -- TRAVA contra registro duplicado
    registrado_em       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (agendamento_id IS NOT NULL OR assinatura_id IS NOT NULL)              -- todo pagamento tem origem
);

CREATE TABLE documentos_fiscais (
    id              BIGSERIAL PRIMARY KEY,
    pagamento_id    BIGINT NOT NULL REFERENCES pagamentos(id),
    tipo            TEXT NOT NULL CHECK (tipo IN ('nfse', 'recibo')),
    solicitado_por  TEXT NOT NULL CHECK (solicitado_por IN ('cliente', 'barbeiro')),
    status          TEXT NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'emitindo', 'emitido', 'erro', 'cancelado')),
    tentativas      SMALLINT NOT NULL DEFAULT 0 CHECK (tentativas BETWEEN 0 AND 3),
    numero          TEXT,
    erro            TEXT,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (pagamento_id, tipo)                                                   -- TRAVA: um de cada tipo por pagamento
);

-- 7) Serviços não oferecidos, com motivo curto escrito pelo dono
CREATE TABLE servicos_nao_oferecidos (
    id                    BIGSERIAL PRIMARY KEY,
    empresa_id            BIGINT NOT NULL REFERENCES empresas(id),
    nome                  TEXT NOT NULL,
    motivo                TEXT NOT NULL CHECK (char_length(motivo) BETWEEN 10 AND 200),  -- TRAVA: MUITO breve
    alternativa_servico_id BIGINT REFERENCES servicos(id)
);

-- 8) Mensagens ativas: novos tipos e até 3 tentativas
-- Remove sobras de teste da migração 002 com tipos antigos (a tabela ainda não tem dados reais)
DELETE FROM envios_ativos WHERE tipo IN ('lembrete_vespera', 'lembrete_2h', 'pos_venda');
ALTER TABLE envios_ativos DROP CONSTRAINT envios_ativos_tipo_check;
ALTER TABLE envios_ativos DROP CONSTRAINT envios_ativos_tentativa_check;
ALTER TABLE envios_ativos
    ADD CONSTRAINT envios_ativos_tipo_check CHECK (tipo IN
        ('lembrete', 'lembrete_reforco', 'conversa_pendente', 'follow_up', 'pos_cancelamento_ou_falta', 'pos_atendimento', 'reativacao')),
    ADD CONSTRAINT envios_ativos_tentativa_check CHECK (tentativa BETWEEN 1 AND 3);

-- 9) Pesquisa de satisfação saiu do fluxo (agora é link do Google para todos)
DROP TABLE avaliacoes;

-- 10) Dados da demo
UPDATE profissionais SET whatsapp = '5511900000010' WHERE nome = 'Rafa';
UPDATE profissionais SET whatsapp = '5511900000011' WHERE nome = 'Diego';
UPDATE empresas SET tom_de_voz = 'Informal, simpático e breve; sem gírias pesadas; poucos emojis' WHERE id = 1;

INSERT INTO servicos_nao_oferecidos (empresa_id, nome, motivo) VALUES
    (1, 'Luzes e descoloração', 'Nosso foco é corte e barba; química de cabelo pede um salão especializado.');

INSERT INTO planos (empresa_id, nome, preco_centavos, cortes_por_mes, beneficios) VALUES
    (1, 'Clube Navalha', 12000, 4, '4 cortes por mês e sobrancelha grátis em todas as visitas');
