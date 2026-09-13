# O gate da R11 trata uma negativa bem-sucedida como inconclusiva — Design (rascunho)

**Data:** 2026-09-12 · Nasceu como rascunho fora da árvore porque `plugin/percus-review/` estava com
16 arquivos no índice de outra janela. A 6.49.0 saiu (`ec0d798`) e a árvore liberou — isto agora é spec.

> ## ⛔ VEREDITO DO CONSELHO: `BLOQUEADA` — não implementar antes de ajustar
>
> `spec-analyze` rodado em 2026-09-12, **2/3** (DeepSeek `BLOQUEADA (1 critical)`, Llama
> `AJUSTAR (1 high)`; a perna Cross-Claude **não rodou** — assimetria declarada, não é consenso 3/3).
>
> **CRITICAL — contradição interna minha.** O desenho recomenda `exit 2` para arquivo descoberto,
> e a seção de Riscos deste mesmo documento declara que *hook novo nasce warn-only*. Ou nasce
> warn-only e a promoção é decisão separada, ou a exceção é registrada e aprovada. Não as duas.
>
> **HIGH — o hash está no objeto errado.** O passo 3 hasheia o arquivo **em disco**
> (`git hash-object <arquivo>`), mas o commit leva o **blob do índice**. Com alteração unstaged, o
> hash validado não é o commitado — o gate aprovaria conteúdo diferente do que vai. Correção:
> `git rev-parse :<path>`.
>
> **HIGH — `git diff --cached --name-only` não é "o que o commit leva".** `git commit <pathspec>`
> pode incluir arquivo não estagiado e excluir estagiado. A lista precisa sair do pathspec real ou o
> gate se restringe a commits sem pathspec.
>
> **HIGH — contradição com o Risco 1.** O desenho afirma que o fallback por tempo passa a ocorrer
> só por erro de cômputo; o Risco 1 admite marcador antigo (sem `arquivos`) caindo no relógio — que
> é justamente uma negativa bem-sucedida sem cobertura, o buraco que a spec existe para fechar.
>
> **HIGH — sem FRs numerados nem SCs mensuráveis.** Os critérios de pronto são testes binários
> isolados, não requisitos rastreáveis.
>
> **MEDIUM** — vazamento WHAT→HOW (comandos, exit codes, schema JSON no corpo da spec); `files` vs
> `arquivos` para o mesmo campo; "recente" e "viu" sem definição; rename e deleção sem regra;
> untracked sem FR nem aceitação explícita.
>
> **O diagnóstico abaixo permanece válido e foi confirmado** — o que está reprovado é o *desenho da
> solução*, não a análise do defeito. Reaproveite o diagnóstico; refaça a partir de "Opções".

## O que este documento decide

Fechar o buraco pelo qual o gate da R11 libera um commit com o review de **outro diff** — sem
tornar o gate impossível de satisfazer numa árvore compartilhada, que é o erro fácil aqui.

## Diagnóstico — e ele desmente a formulação inicial

A formulação que circulou entre as janelas hoje foi: *"o `pre-commit-check` só pergunta se existe
review com menos de 5 min; nunca pergunta se esse review olhou o que vou commitar"*. **Isso está
errado**, e vale registrar porque eu quase escrevi um conserto para o problema errado.

O hook **pergunta sim** (`pre-commit-check.ps1:134-171`), e o desenho é bom:

1. Calcula `sha256(git diff HEAD)`, 12 hex.
2. Procura `.deepseek/reviews/d-<hash>.jsonl`.
3. Achou e tem menos de 24 h → `exit 0`. **Validade por conteúdo, antes da validade por tempo.**

O comentário no código explica a intenção com precisão: *"Tempo nunca foi proxy de 'isto foi
revisado'"*. Há inclusive dois cuidados finos já resolvidos ali — usa `git diff HEAD` (não
`--cached`) para que `editar → revisar → stage → commit` não invalide a review no meio, e escreve o
diff com `--output=` porque capturar a saída pelo shell produz hash diferente entre PowerShell e
bash quando há acento.

**O defeito não é a ausência da pergunta. É o que acontece com a resposta "não".**

```powershell
try {
    ... calcula $hashHex ...
    $porHash = Join-Path $reviewDir "d-$hashHex.jsonl"
    if (Test-Path $porHash) {
        if ($idade.TotalHours -le 24) { exit 0 }
    }
} catch { }
# cai aqui: latest.jsonl + 5 min
```

O `catch` vazio e o `if` que não casa **desembocam no mesmo lugar**. O comentário declara a
intenção — *"Falha graceful: qualquer erro aqui cai no caminho antigo"* — e a intenção é legítima:
se o hash não pôde ser **computado**, não dá para concluir nada, e cair no relógio é razoável.

Mas o `Test-Path` retornando `$false` **não é um erro**: é uma medição bem-sucedida cujo resultado é
*"nenhum review cobriu este diff"*. O código não distingue **"não consegui perguntar"** de
**"perguntei e a resposta é não"**, e trata as duas como inconclusivas. A negativa bem-sucedida —
que é exatamente o sinal que o gate existe para capturar — é descartada em favor de um critério mais
fraco.

### Por que isso é a regra, não a exceção, em árvore compartilhada

`git diff HEAD` é o diff da **árvore inteira**. Com mais de uma janela trabalhando:

- a janela A roda review → grava `d-<hashA>.jsonl`
- a janela B escreve qualquer arquivo, em qualquer pasta → `git diff HEAD` muda → o hash muda
- A commita → o lookup falha → **cai no relógio** → passa com o review de quem quer que tenha
  rodado por último

Medido hoje nesta árvore: `.deepseek/reviews/latest.jsonl` continha
`scope: "conhecimento/resolver/INDICE.md (1 linha)"` enquanto uma janela se preparava para commitar
**845 linhas**. O caminho por conteúdo estava correto e foi ignorado.

### O detalhe que torna o conserto ingênuo perigoso

Fazer o óbvio — *"se o hash foi computado e não casou, bloqueie"* — **trava a árvore compartilhada**.
Qualquer edição de qualquer janela, em qualquer arquivo não relacionado, invalidaria a sua review.
Com 5 janelas ativas, ninguém commita nunca, e o resultado previsível é `PERCUS_HOOKS_DISABLED`
virando rotina — o mesmo desfecho do teto do `CONTEXT.md`, que é a lição que o kit repete para si
mesmo.

**O problema real não é o fallback existir. É a granularidade da pergunta:** o gate pergunta sobre a
árvore inteira quando deveria perguntar sobre *o que este commit leva*.

## Opções

### A — Distinguir erro de negativa (mínima)

Sinalizar se o hash foi computado. Computado e sem marcador → bloqueia. Não computado → relógio.

- ✅ Cirúrgica, ~6 linhas, mata o buraco.
- ❌ **Trava a árvore compartilhada** pelo motivo acima. Inaceitável sozinha.

### B — Hash só do que vai ser commitado

Restringir o diff ao pathspec do comando; sem pathspec, usar `--cached`.

- ✅ Correta em árvore compartilhada.
- ❌ Exige interpretar pathspec da linha de comando — frágil, e o `pre-commit-check` já foi mordido
  por casar comando como texto (barrou dois comandos de teste hoje).

### C — Marcador registra a lista de arquivos; o gate checa cobertura

O review grava `files: [...]`; o gate exige que todo arquivo do commit esteja coberto.

- ✅ Explicável e robusta.
- ❌ Cobertura por **nome** não detecta que o arquivo **mudou** depois da review.

### D — Marcador registra hash por arquivo *(recomendada)*

O review grava, para cada arquivo que viu, o `git hash-object` do conteúdo. O gate, para cada
arquivo que o commit leva, exige que algum review recente tenha registrado **aquele mesmo hash**.

- ✅ Imune a edição de terceiros: a janela B mexer em `outro.ts` não invalida a sua review de
  `seu.ts`, porque o hash de `seu.ts` não mudou.
- ✅ Detecta edição do **seu** arquivo depois da review — que é o caso que o gate existe para pegar.
- ✅ Preserva a propriedade O(1) por arquivo (lookup direto, sem enumerar o diretório).
- ✅ O fallback por tempo deixa de ser alcançável por negativa: só por erro de cômputo.
- ❌ Exige mudança nos **dois** lados (quem escreve o marcador e quem lê).

## Desenho recomendado (D)

**No escritor do review** (`scripts/percus-review-auto.ps1` e os wrappers): acrescentar ao marcador

```json
"arquivos": { "caminho/relativo.ts": "<git hash-object>", ... }
```

`git diff HEAD --name-only` dá a lista; `git hash-object <arquivo>` dá o hash do conteúdo em disco.
Arquivo deletado entra com hash vazio. Manter `d-<hash-do-diff>.jsonl` como está — é o caminho
rápido e continua valendo quando nada mudou na árvore.

**No gate** (`pre-commit-check.ps1`), substituindo o bloco 134-171:

1. Caminho rápido inalterado: hash do diff inteiro casa → `exit 0`.
2. Não casou: determinar os arquivos do commit — `git diff --cached --name-only` (o que está
   estagiado é o que o commit leva, com ou sem pathspec).
3. Para cada um, calcular `git hash-object` e procurar nos marcadores das últimas 24 h um que
   registre aquele par arquivo→hash.
4. **Todos cobertos** → `exit 0`.
5. **Algum descoberto** → `exit 2`, nomeando *quais* arquivos e dizendo se é "nunca revisado" ou
   "revisado numa versão anterior" — a mesma distinção de três estados do `spec-analyze-check`.
6. **Erro de cômputo em qualquer ponto** → aí sim o fallback por tempo, que passa a ser o que o
   comentário sempre disse que era.

## Critério de pronto

1. Teste: janela A revisa `a.txt`, janela B edita `b.txt`, A commita `a.txt` → **passa**. É o caso
   que a opção A quebraria e o que torna a árvore compartilhada viável.
2. Teste: revisa `a.txt`, edita `a.txt` depois, commita → **bloqueia**, dizendo "versão anterior".
3. Teste: review de 1 linha em `x.md` não libera commit de `y.ps1` — o caso medido hoje.
4. Teste: falha de cômputo (repo sem `git`, `--output=` falhando) → cai no relógio, não bloqueia.
5. Paridade `.ps1`/`.sh` com teste que roda o `.sh` de verdade.
6. Suíte inteira verde.

## Riscos

1. **Mudança nos dois lados**: marcador velho (sem `arquivos`) tem que continuar funcionando, senão
   todo commit bloqueia até o primeiro review novo. O gate trata marcador sem `arquivos` como
   "não cobre nada" e cai no relógio — degradação suave.
2. **`git hash-object` por arquivo** custa um processo por arquivo. Commit de 100 arquivos = 100
   processos. Mitigação: `git hash-object` aceita múltiplos caminhos numa chamada.
3. **Não cobre untracked**: arquivo novo não aparece em `git diff HEAD`, então não é revisado nem
   registrado. Foi assim que uma review reportou "1 arquivo(s)" com dois verbetes novos no disco.
   Isto é um buraco **separado e anterior** — registrar como dívida, não resolver aqui.
4. O gate fica mais estrito que hoje. Publicar com aviso antes de bloqueio, pela regra do kit
   (hook novo nasce warn-only).

## Nota de método

O diagnóstico inicial — *"o gate só olha o relógio"* — descrevia o **efeito** e errava a **causa**, e
levaria a reimplementar um mecanismo que já existe e funciona. A causa é uma linha de controle de
fluxo onde um `catch` vazio e um `if` que não casa desembocam no mesmo ponto.

Classe generalizável, e vale verbete próprio: **negativa bem-sucedida tratada como inconclusiva.**
Sempre que um caminho de erro e um resultado negativo compartilham o mesmo destino, o sistema perde
exatamente o sinal que ele foi construído para detectar — e perde calado, porque o caminho
degradado responde "ok".
