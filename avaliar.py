"""
Avaliador do golden set — dá a nota do Villa nas 100 conversas.

Uso:
    python avaliar.py                  -> roda tudo e salva o relatório em relatorios/
    python avaliar.py --categoria preco -> roda só uma categoria
    python avaliar.py --mostrar-falhas  -> lista cada falha no terminal

Critérios (Portão 1):
    - acerto geral >= 90%
    - zero falhas críticas (algo proibido apareceu na resposta: preço inventado,
      dado de terceiro, promessa de dinheiro, pergunta de motivo...)
"""
import argparse
import json
import sys
import time
import unicodedata
from collections import defaultdict
from datetime import datetime
from pathlib import Path

from app.agente import processar

ARQUIVO = Path("tests/golden/conversas.jsonl")
PASTA_RELATORIOS = Path("relatorios")
META_ACERTO = 0.90


def normalizar(texto: str | None) -> str:
    """Minúsculas e sem acentos: 'Débito' e 'debito' contam igual."""
    if not texto:
        return ""
    sem_acento = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return " ".join(sem_acento.lower().split())


def corrigir(conversa: dict, resposta: dict) -> dict:
    """Compara a resposta do agente com o gabarito. Devolve o resultado detalhado."""
    esp = conversa["esperado"]
    texto = normalizar(resposta.get("texto"))
    faltou = [p for p in esp["deve_conter"] if normalizar(p) not in texto]
    proibidas = [p for p in esp["nao_pode_conter"] if normalizar(p) in texto]
    intencao_ok = normalizar(resposta.get("intencao")) == normalizar(esp["intencao"])
    acao_ok = resposta.get("acao") == esp["acao"]
    return {
        "id": conversa["id"],
        "categoria": conversa["categoria"],
        "passou": intencao_ok and acao_ok and not faltou and not proibidas,
        "critica": bool(proibidas),
        "intencao_ok": intencao_ok,
        "acao_ok": acao_ok,
        "faltou": faltou,
        "proibidas": proibidas,
        "esperado": esp,
        "obtido": {"intencao": resposta.get("intencao"), "acao": resposta.get("acao"), "texto": resposta.get("texto")},
        "origem": conversa.get("origem", "humano"),
    }


def motivo_da_falha(r: dict) -> str:
    partes = []
    if r["proibidas"]:
        partes.append(f"CRÍTICA: disse {r['proibidas']}")
    if not r["intencao_ok"]:
        partes.append(f"intenção {r['obtido']['intencao']!r} ≠ {r['esperado']['intencao']!r}")
    if not r["acao_ok"]:
        partes.append(f"ação {r['obtido']['acao']!r} ≠ {r['esperado']['acao']!r}")
    if r["faltou"]:
        partes.append(f"faltou {r['faltou']}")
    return "; ".join(partes)


def salvar_relatorio(resultados: list[dict], resumo: dict) -> Path:
    PASTA_RELATORIOS.mkdir(exist_ok=True)
    caminho = PASTA_RELATORIOS / f"avaliacao_{datetime.now():%Y-%m-%d_%H%M}.md"
    linhas = [
        f"# Avaliação do golden set — {datetime.now():%d/%m/%Y %H:%M}", "",
        f"- Acerto geral: **{resumo['acerto']:.0%}** ({resumo['passou']}/{resumo['total']}) — meta {META_ACERTO:.0%}",
        f"- Falhas críticas: **{resumo['criticas']}** — meta 0",
        f"- Acerto nas conversas humanas: {resumo['acerto_humano']:.0%} · nas do rascunho de IA: {resumo['acerto_ia']:.0%}",
        f"- Tempo médio por conversa: {resumo['tempo_medio_ms']:.0f} ms", "",
        "## Por categoria", "", "| Categoria | Acerto |", "| --- | --- |",
    ]
    for cat, (ok, tot) in sorted(resumo["por_categoria"].items()):
        linhas.append(f"| {cat} | {ok}/{tot} |")
    linhas += ["", "## Falhas", "", "| id | Motivo |", "| --- | --- |"]
    for r in resultados:
        if not r["passou"]:
            linhas.append(f"| {r['id']} | {motivo_da_falha(r)} |")
    caminho.write_text("\n".join(linhas) + "\n", encoding="utf-8")
    return caminho


def main() -> int:
    parser = argparse.ArgumentParser(description="Avalia o Villa no golden set")
    parser.add_argument("--categoria", help="roda só esta categoria")
    parser.add_argument("--mostrar-falhas", action="store_true", help="lista cada falha no terminal")
    args = parser.parse_args()

    print("[1/4] Lendo o golden set...")
    conversas = [json.loads(l) for l in ARQUIVO.read_text(encoding="utf-8").splitlines() if l.strip()]
    if args.categoria:
        conversas = [c for c in conversas if c["categoria"] == args.categoria]
    print(f"      ✔ {len(conversas)} conversas\n")

    print("[2/4] Rodando o agente...")
    resultados, tempos = [], []
    for i, conversa in enumerate(conversas, start=1):
        inicio = time.perf_counter()
        resposta = processar(conversa["mensagens"], conversa.get("remetente", "cliente"))
        tempos.append((time.perf_counter() - inicio) * 1000)
        r = corrigir(conversa, resposta)
        resultados.append(r)
        marca = "✔" if r["passou"] else ("✘!" if r["critica"] else "✘")
        print(f"      [{i:>3}/{len(conversas)}] {marca} {r['id']}")
    print()

    print("[3/4] Calculando a nota...")
    por_cat = defaultdict(lambda: [0, 0])
    for r in resultados:
        por_cat[r["categoria"]][1] += 1
        por_cat[r["categoria"]][0] += r["passou"]
    humanos = [r for r in resultados if r["origem"] != "rascunho_ia"]
    ia = [r for r in resultados if r["origem"] == "rascunho_ia"]
    taxa = lambda grupo: sum(r["passou"] for r in grupo) / len(grupo) if grupo else 0.0
    resumo = {
        "total": len(resultados), "passou": sum(r["passou"] for r in resultados),
        "acerto": taxa(resultados), "criticas": sum(r["critica"] for r in resultados),
        "acerto_humano": taxa(humanos), "acerto_ia": taxa(ia),
        "tempo_medio_ms": sum(tempos) / len(tempos) if tempos else 0,
        "por_categoria": {k: tuple(v) for k, v in por_cat.items()},
    }
    print(f"      Acerto geral:     {resumo['acerto']:.0%}  ({resumo['passou']}/{resumo['total']})   meta {META_ACERTO:.0%}")
    print(f"      Falhas críticas:  {resumo['criticas']}   meta 0")
    print(f"      Humanas × IA:     {resumo['acerto_humano']:.0%} × {resumo['acerto_ia']:.0%}\n")
    if args.mostrar_falhas:
        for r in resultados:
            if not r["passou"]:
                print(f"      ✘ {r['id']}: {motivo_da_falha(r)}")
        print()

    print("[4/4] Salvando relatório...")
    caminho = salvar_relatorio(resultados, resumo)
    print(f"      ✔ {caminho}\n")

    aprovado = resumo["acerto"] >= META_ACERTO and resumo["criticas"] == 0
    print("✔ APROVADO no critério do Portão 1" if aprovado else "✘ Ainda abaixo do critério do Portão 1")
    return 0 if aprovado else 1


if __name__ == "__main__":
    sys.exit(main())
