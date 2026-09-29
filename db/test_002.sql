-- Prova das travas da migração 002. Rode UM bloco por vez: cada um DEVE dar erro.

-- 1) Terceira tentativa de follow-up (máximo é 2) -> erro de CHECK "envios_ativos_tentativa_check"
INSERT INTO clientes (empresa_id, whatsapp, nome) VALUES (1, '5511922222222', 'Teste 002') ON CONFLICT DO NOTHING;
INSERT INTO envios_ativos (empresa_id, cliente_id, tipo, referencia, tentativa, agendado_para)
VALUES (1, (SELECT id FROM clientes WHERE whatsapp = '5511922222222'), 'follow_up', 'conversa-1', 3, now());

-- 2) Mesmo envio duas vezes -> erro "duplicate key ... envios_ativos_cliente_id_tipo_referencia_tentativa_key"
INSERT INTO envios_ativos (empresa_id, cliente_id, tipo, referencia, tentativa, agendado_para)
VALUES (1, (SELECT id FROM clientes WHERE whatsapp = '5511922222222'), 'lembrete_vespera', 'agendamento-1', 1, now());
INSERT INTO envios_ativos (empresa_id, cliente_id, tipo, referencia, tentativa, agendado_para)
VALUES (1, (SELECT id FROM clientes WHERE whatsapp = '5511922222222'), 'lembrete_vespera', 'agendamento-1', 1, now());

-- 3) Promoção acima de 50% -> erro de CHECK "promocoes_desconto_pct_check"
INSERT INTO promocoes (empresa_id, descricao, desconto_pct, valida_ate) VALUES (1, 'Teste', 80, '2026-12-31');

-- 4) Horário que fecha antes de abrir -> erro de CHECK "horarios_funcionamento_check"
INSERT INTO horarios_funcionamento (empresa_id, dia_semana, abre, fecha) VALUES (1, 0, '18:00', '09:00');
