"""
Agente do Villa — ponto único de entrada para o avaliador e, depois, para o webhook.

Fase 1 vai substituir este corpo pelo agente real (roteador + ferramentas + travas).
Por enquanto é uma LINHA DE BASE que não entende nada: serve para provar que o
avaliador funciona e para medir o ponto de partida.
"""


def processar(mensagens: list[str], remetente: str = "cliente") -> dict:
    """Recebe as mensagens agrupadas de uma conversa e devolve texto, intenção e ação."""
    return {
        "texto": "Olá! Sou o assistente virtual da Barbearia Navalha de Ouro.",
        "intencao": "indefinida",
        "acao": None,
    }
