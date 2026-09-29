"""
Golden set — validação de formato (pytest) e relatório de progresso (python).

    python -m pytest tests/test_golden.py -v   -> confere se cada linha está no formato certo
    python tests/test_golden.py                -> mostra quantas conversas faltam por categoria
"""
import json
from collections import Counter
from pathlib import Path

ARQUIVO = Path(__file__).parent / "golden" / "conversas.jsonl"

# Meta do Portão 0: 100 conversas nesta distribuição (fluxo v1.0)
META = {
    "saudacao": 5, "preco": 10, "preco_inexistente": 5, "agendar": 14, "remarcar": 6,
    "cancelar": 5, "horario_funcionamento": 4, "endereco": 2, "pagamento": 4, "plano": 5,
    "barbeiro": 6, "transferencia": 4, "lgpd": 5, "dono": 5, "ambiguo": 5,
    "fora_do_escopo": 5, "red_team": 10,
}
CATEGORIAS_DE_ERRO = {"preco_inexistente", "ambiguo", "fora_do_escopo", "red_team"}
META_ERRO = 20


def carregar() -> list[tuple[int, dict]]:
    linhas = []
    for n, texto in enumerate(ARQUIVO.read_text(encoding="utf-8").splitlines(), start=1):
        if texto.strip():
            linhas.append((n, json.loads(texto)))
    return linhas


def problemas_da_linha(n: int, c: dict) -> list[str]:
    erros = []
    if not isinstance(c.get("id"), str) or not c["id"]:
        erros.append(f"linha {n}: 'id' ausente ou vazio")
    if c.get("categoria") not in META:
        erros.append(f"linha {n}: categoria '{c.get('categoria')}' não existe. Use uma de: {', '.join(META)}")
    msgs = c.get("mensagens")
    if not isinstance(msgs, list) or not msgs or not all(isinstance(m, str) and m.strip() for m in msgs):
        erros.append(f"linha {n}: 'mensagens' deve ser uma lista de textos não vazios")
    if c.get("remetente", "cliente") not in ("cliente", "dono", "barbeiro"):
        erros.append(f"linha {n}: 'remetente' deve ser 'cliente', 'dono' ou 'barbeiro'")
    if c.get("categoria") in ("dono", "barbeiro") and c.get("remetente") != c.get("categoria"):
        erros.append(f"linha {n}: na categoria '{c.get('categoria')}' use \"remetente\": \"{c.get('categoria')}\"")
    esp = c.get("esperado")
    if not isinstance(esp, dict):
        erros.append(f"linha {n}: 'esperado' ausente")
    else:
        if not isinstance(esp.get("intencao"), str) or not esp["intencao"]:
            erros.append(f"linha {n}: 'esperado.intencao' ausente")
        for campo in ("deve_conter", "nao_pode_conter"):
            if not isinstance(esp.get(campo), list):
                erros.append(f"linha {n}: 'esperado.{campo}' deve ser uma lista (pode ser vazia)")
        if "acao" not in esp:
            erros.append(f"linha {n}: 'esperado.acao' ausente (use null quando não houver)")
    return erros


def test_todas_as_linhas_sao_json_valido():
    for n, texto in enumerate(ARQUIVO.read_text(encoding="utf-8").splitlines(), start=1):
        if texto.strip():
            try:
                json.loads(texto)
            except json.JSONDecodeError as e:
                raise AssertionError(f"linha {n} não é JSON válido: {e}") from None


def test_formato_de_cada_conversa():
    erros = [e for n, c in carregar() for e in problemas_da_linha(n, c)]
    assert not erros, "\n".join(erros)


def test_ids_unicos():
    ids = Counter(c["id"] for _, c in carregar())
    repetidos = [i for i, q in ids.items() if q > 1]
    assert not repetidos, f"ids repetidos: {repetidos}"


if __name__ == "__main__":
    print("[1/3] Lendo o golden set...")
    conversas = carregar()
    print(f"      ✔ {len(conversas)} conversas encontradas\n")

    print("[2/3] Conferindo formato...")
    erros = [e for n, c in conversas for e in problemas_da_linha(n, c)]
    for e in erros:
        print(f"      ✘ {e}")
    print("      ✔ formato OK\n" if not erros else "")

    print("[3/3] Progresso por categoria:")
    contagem = Counter(c.get("categoria") for _, c in conversas)
    for cat, meta in META.items():
        feito = contagem.get(cat, 0)
        marca = "✔" if feito >= meta else " "
        print(f"      {marca} {cat:<22} {feito:>3} / {meta}")
    total = sum(contagem.get(c, 0) for c in META)
    erro = sum(contagem.get(c, 0) for c in CATEGORIAS_DE_ERRO)
    print(f"\n      Total: {total} / 100    Casos de erro ou ataque: {erro} / {META_ERRO}")
    pronto = not erros and total >= 100 and erro >= META_ERRO and all(contagem.get(c, 0) >= m for c, m in META.items())
    print("\n✔ Golden set pronto para o Portão 0!" if pronto else "\n… Ainda não chegou na meta. Continue escrevendo.")
