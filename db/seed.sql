-- Negócio fictício da demo. Troque o número do dono pelo SEU WhatsApp (formato 55DDDNUMERO).
INSERT INTO empresas (nome, whatsapp_dono) VALUES ('Barbearia Navalha de Ouro', '5511986778319');

INSERT INTO servicos (empresa_id, nome, preco_centavos, duracao_min) VALUES
    (1, 'Corte masculino', 4500, 30),
    (1, 'Barba', 3500, 30),
    (1, 'Corte + barba', 7000, 60),
    (1, 'Pezinho', 1500, 15),
    (1, 'Sobrancelha', 2000, 15);

INSERT INTO profissionais (empresa_id, nome) VALUES (1, 'Rafa'), (1, 'Diego');
