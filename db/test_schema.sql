-- Prova das travas: cada bloco deve FALHAR. Rodar depois do seed.
INSERT INTO clientes (empresa_id, whatsapp, nome) VALUES (1, '5511911111111', 'Teste');
INSERT INTO agendamentos (empresa_id, cliente_id, servico_id, profissional_id, periodo)
VALUES (1, 1, 1, 1, '[2026-10-10 10:00-03, 2026-10-10 10:30-03)');
-- deve falhar com "sem_conflito":
INSERT INTO agendamentos (empresa_id, cliente_id, servico_id, profissional_id, periodo)
VALUES (1, 1, 2, 1, '[2026-10-10 10:15-03, 2026-10-10 10:45-03)');
