-- Funcionário de IA — migração 004: dados do local (faltavam para o fluxo F02)
-- Rodar no SQL Editor do Supabase DEPOIS da 003

ALTER TABLE empresas
    ADD COLUMN endereco          TEXT CHECK (endereco IS NULL OR char_length(endereco) BETWEEN 10 AND 200),
    ADD COLUMN referencia        TEXT CHECK (referencia IS NULL OR char_length(referencia) <= 200),   -- "ao lado da padaria X"
    ADD COLUMN link_mapa         TEXT CHECK (link_mapa IS NULL OR link_mapa LIKE 'https://%'),
    ADD COLUMN observacoes_local TEXT CHECK (observacoes_local IS NULL OR char_length(observacoes_local) <= 300); -- estacionamento, acessibilidade

-- Dados fictícios da demo
UPDATE empresas
SET endereco   = 'Rua Exemplo, 123 - Centro, Diadema/SP',
    referencia = 'Em frente à praça central'
WHERE id = 1;
