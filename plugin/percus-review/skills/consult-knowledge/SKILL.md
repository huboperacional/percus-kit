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

1. **Comece pelo Índice** (o bloco `- [...](#ancora)` no topo), não pelo arquivo.
   ⚠️ **Não leia o arquivo inteiro.** A instrução anterior aqui dizia que ele "é pequeno e cabe no
   contexto" — era verdade quando foi escrita e hoje é falso: `COMO_RESOLVER.md` passou de
   **900 KB / ~230k tokens** (medido 2026-08-16).
   **Tamanhos reais, para você escolher com informação:** o Índice sozinho tem **339 linhas / ~45 KB
   (~13k tokens)** — cabe, mas não é de graça; um verbete típico tem **3–6 KB**. Precisa de visão
   ampla? Leia o Índice. Já tem hipótese de classe? Busque no Índice pelos termos da classe e leia
   só o verbete escolhido.
2. **Olhe também a caixa de entrada** — `conhecimento/entrada/resolver/` e `conhecimento/entrada/fazer/`.
   São verbetes já escritos que ainda não foram mesclados no monólito (o merge acontece no
   `checkpoint`). Cada arquivo é um verbete, e o **nome do arquivo é o slug** — dá pra varrer os nomes
   e ler só o que interessa. Pular a caixa é reintroduzir o problema de conhecimento escrito e
   invisível, que já custou 5 entradas perdidas de vista.
3. **Case por CLASSE de sintoma**, não por texto exato: a linha `tags:` de cada entrada lista a classe
   de erro, componente e termos locale-independentes. Raciocine sobre relevância ("meu erro é um parser
   error num `.ps1` rodado via `.cmd`" → casa com `ps51-ascii-hooks` mesmo que a mensagem seja outra).
4. Se houver entrada que case a classe, **tente a solução de lá primeiro** antes de investigar do zero.
5. Se **nada** casar, debugue normalmente — e ao resolver, volte pra registrar (passo abaixo).

## Como registrar (após resolver algo novo)

**Escreva na CAIXA DE ENTRADA, não no monólito** — um verbete por arquivo:

```
conhecimento/entrada/resolver/<slug>.md    # troubleshooting
conhecimento/entrada/fazer/<slug>.md       # procedimento
```

O **nome do arquivo tem de ser exatamente o slug** da âncora (`{#slug}`) — o gate barra se divergir.
Formato do conteúdo é o mesmo de sempre, e a `tags:` continua sendo o que faz o próximo lookup achar:

- Troubleshooting: `## <sintoma> {#ancora}` · `tags:` · Contexto · Causa raiz · Solução · Ref.
- Procedimento: `## <objetivo> {#ancora}` · `tags:` · Quando · Passos · Comando · Armadilhas.

**Não atualize o Índice à mão, e não edite `COMO_RESOLVER.md` direto.** O `checkpoint` roda
`scripts/mesclar-conhecimento.ps1`, que anexa o verbete e insere a linha de índice sozinho.

**Por quê:** o monólito tem centenas de verbetes num arquivo só, e o git resolve conflito em
**arquivo**. Duas sessões escrevendo lições sobre assuntos diferentes colidiam assim mesmo — medido
2026-08-16, um commit levaria junto o rascunho inacabado de outra sessão. Arquivos separados = colisão
zero. Use **caminho absoluto** nas refs.

## Anti-padrões

- ❌ `grep` literal no sintoma e concluir "não tem nada" — sintomas variam; leia e case por classe.
- ❌ Debugar 30 min um problema que já estava catalogado (não consultou) — R23.
- ❌ Resolver incidente não-trivial e encerrar sem registrar — conhecimento se perde (R23).
- ❌ Inventar procedimento de deploy/infra divergente do `COMO_FAZER.md` sem atualizar o doc.

## Referências

- Regra: `${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md` R23.
- Gates de captura: `checklists/CHECKLIST_ENCERRAR_SESSAO.md` (passo 3.5), skill `percus-review:checkpoint`.
- Base: `conhecimento/COMO_RESOLVER.md`, `conhecimento/COMO_FAZER.md`.
