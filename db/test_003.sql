-- Prova das travas da migração 003. Rode UM bloco por vez, numa query nova: cada um DEVE dar erro.
-- Os blocos criam os próprios dados de teste; pode rodar em qualquer ordem.

-- BLOCO 1) Falta sem barbeiro -> erro "falta_exige_barbeiro"
INSERT INTO clientes (empresa_id, whatsapp, nome) VALUES (1, '5511933333301', 'Teste 003-1') ON CONFLICT DO NOTHING;
INSERT INTO agendamentos (empresa_id, cliente_id, servico_id, profissional_id, periodo, status)
VALUES (1, (SELECT id FROM clientes WHERE whatsapp = '5511933333301'), 1, 1,
        '[2026-11-03 10:00-03, 2026-11-03 10:30-03)', 'faltou');

-- BLOCO 2) Forma de pagamento inválida -> erro "pagamentos_forma_check"
INSERT INTO clientes (empresa_id, whatsapp, nome) VALUES (1, '5511933333302', 'Teste 003-2') ON CONFLICT DO NOTHING;
INSERT INTO agendamentos (empresa_id, cliente_id, servico_id, profissional_id, periodo)
VALUES (1, (SELECT id FROM clientes WHERE whatsapp = '5511933333302'), 1, 2, '[2026-11-03 11:00-03, 2026-11-03 11:30-03)');
INSERT INTO pagamentos (empresa_id, cliente_id, agendamento_id, valor_centavos, forma, registrado_por, canal, chave_idempotencia)
VALUES (1, (SELECT id FROM clientes WHERE whatsapp = '5511933333302'),
        (SELECT max(id) FROM agendamentos), 4500, 'cheque', 1, 'texto', 'teste-003-2');

-- BLOCO 3) Quarta tentativa de follow-up -> erro "envios_ativos_tentativa_check"
INSERT INTO clientes (empresa_id, whatsapp, nome) VALUES (1, '5511933333303', 'Teste 003-3') ON CONFLICT DO NOTHING;
INSERT INTO envios_ativos (empresa_id, cliente_id, tipo, referencia, tentativa, agendado_para)
VALUES (1, (SELECT id FROM clientes WHERE whatsapp = '5511933333303'), 'follow_up', 'conversa-99', 4, now());

-- BLOCO 4) Usar mais cortes que o plano inclui -> erro "assinaturas_check1"
INSERT INTO clientes (empresa_id, whatsapp, nome) VALUES (1, '5511933333304', 'Teste 003-4') ON CONFLICT DO NOTHING;
INSERT INTO assinaturas (cliente_id, plano_id, inicio, valida_ate, cortes_incluidos, cortes_usados)
VALUES ((SELECT id FROM clientes WHERE whatsapp = '5511933333304'), 1, '2026-11-01', '2026-12-01', 4, 5);

-- BLOCO 5) Duas assinaturas ativas para o mesmo cliente -> erro "uma_assinatura_ativa"
INSERT INTO clientes (empresa_id, whatsapp, nome) VALUES (1, '5511933333305', 'Teste 003-5') ON CONFLICT DO NOTHING;
INSERT INTO assinaturas (cliente_id, plano_id, inicio, valida_ate, cortes_incluidos)
VALUES ((SELECT id FROM clientes WHERE whatsapp = '5511933333305'), 1, '2026-11-01', '2026-12-01', 4);
INSERT INTO assinaturas (cliente_id, plano_id, inicio, valida_ate, cortes_incluidos)
VALUES ((SELECT id FROM clientes WHERE whatsapp = '5511933333305'), 1, '2026-11-01', '2026-12-01', 4);

-- BLOCO 6) Motivo longo demais para serviço não oferecido -> erro "servicos_nao_oferecidos_motivo_check"
INSERT INTO servicos_nao_oferecidos (empresa_id, nome, motivo)
VALUES (1, 'Teste', repeat('motivo longo demais ', 20));
