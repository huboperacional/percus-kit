---
name: consult-knowledge
description: Use ANTES de gastar tempo debugando um problema que parece conhecido, OU ao precisar do procedimento-base canônico de uma tarefa recorrente (deploy, git, migration). Lê a base de conhecimento Percus (conhecimento/COMO_RESOLVER.md + COMO_FAZER.md) e casa por CLASSE de sintoma, não string literal. Também usada ao FIM de um problema resolvido, para registrar a solução (R23).
---

# Percus — Consultar Base de Conhecimento (R23)

Base cross-projeto versionada no canon. Dois arquivos, dois propósitos:
- `${env:PERCUS_CANON_DIR}/conhecimento/COMO_RESOLVER.md` — **problema → solução** (troubleshooting).
- `${env:PERCUS_CANON_DIR}/conhecimento/COMO_FAZER.md` — **procedimento-base** (como fazer X canônico).

## Quando usar

- **Bateu num erro/comportamento estranho que parece conhecido** → CONSULTE antes de debugar do zero.
- **Vai fazer uma tarefa recorrente** (commit/review, rodar conselho, migration, deploy) → confira o padrão.
- **Acabou de resolver um problema não-trivial** → REGISTRE a solução (gate R23 / `CHECKLIST_ENCERRAR_SESSAO`).

## Como consultar — lookup SEMÂNTICO, não grep

> ⚠️ **Não dependa de `grep` por string literal.** Sintomas reais variam em wording, stack e locale —
> a mesma falha aparece com mensagens diferentes. Grep dá falso-negativo na maioria das consultas.

1. **Leia o arquivo inteiro** (`COMO_RESOLVER.md` é pequeno e cabe no contexto) — ou ao menos o Índice.
2. **Case por CLASSE de sintoma**, não por texto exato: a linha `tags:` de cada entrada lista a classe
   de erro, componente e termos locale-independentes. Raciocine sobre relevância ("meu erro é um parser
   error num `.ps1` rodado via `.cmd`" → casa com `ps51-ascii-hooks` mesmo que a mensagem seja outra).
3. Se houver entrada que case a classe, **tente a solução de lá primeiro** antes de investigar do zero.
4. Se **nada** casar, debugue normalmente — e ao resolver, volte pra registrar (passo abaixo).

## Como registrar (após resolver algo novo)

Adicione uma entrada no arquivo certo, com `tags:` rica (é o que faz o próximo lookup achar):

- Troubleshooting → `COMO_RESOLVER.md`: `## <sintoma> {#ancora}` · `tags:` · Contexto · Causa raiz · Solução · Ref.
- Procedimento → `COMO_FAZER.md`: `## <objetivo> {#ancora}` · `tags:` · Quando · Passos · Comando · Armadilhas.

Atualize o Índice do arquivo. Use **caminho absoluto** nas refs.

## Anti-padrões

- ❌ `grep` literal no sintoma e concluir "não tem nada" — sintomas variam; leia e case por classe.
- ❌ Debugar 30 min um problema que já estava catalogado (não consultou) — R23.
- ❌ Resolver incidente não-trivial e encerrar sem registrar — conhecimento se perde (R23).
- ❌ Inventar procedimento de deploy/infra divergente do `COMO_FAZER.md` sem atualizar o doc.

## Referências

- Regra: `${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md` R23.
- Gates de captura: `checklists/CHECKLIST_ENCERRAR_SESSAO.md` (passo 3.5), skill `percus-review:checkpoint`.
- Base: `conhecimento/COMO_RESOLVER.md`, `conhecimento/COMO_FAZER.md`.
