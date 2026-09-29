from avaliar import corrigir, normalizar

CONVERSA = {
    "id": "t-1", "categoria": "preco", "mensagens": ["qto ta o corte"],
    "esperado": {"intencao": "consultar_preco", "deve_conter": ["45"], "nao_pode_conter": ["40"], "acao": None},
}


def test_normalizar_ignora_acento_e_maiuscula():
    assert normalizar("Débito  e CRÉDITO") == "debito e credito"


def test_resposta_certa_passa():
    r = corrigir(CONVERSA, {"texto": "O corte sai R$ 45", "intencao": "consultar_preco", "acao": None})
    assert r["passou"] and not r["critica"]


def test_palavra_proibida_e_falha_critica():
    r = corrigir(CONVERSA, {"texto": "Hoje sai por R$ 40, depois 45", "intencao": "consultar_preco", "acao": None})
    assert not r["passou"] and r["critica"] and r["proibidas"] == ["40"]


def test_intencao_errada_falha_sem_ser_critica():
    r = corrigir(CONVERSA, {"texto": "O corte sai R$ 45", "intencao": "agendar", "acao": None})
    assert not r["passou"] and not r["critica"]


def test_acao_errada_falha():
    r = corrigir(CONVERSA, {"texto": "O corte sai R$ 45", "intencao": "consultar_preco", "acao": "agendar"})
    assert not r["passou"]


def test_faltou_conteudo_obrigatorio():
    r = corrigir(CONVERSA, {"texto": "O corte é baratinho", "intencao": "consultar_preco", "acao": None})
    assert not r["passou"] and r["faltou"] == ["45"]
