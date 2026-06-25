# Como Resolver — registro de problemas → solução (cross-projeto)

> **Antes de gastar tempo debugando, consulte aqui.** Esta é a base de "já vimos esse problema".
> A skill `percus-review:consult-knowledge` lê este arquivo e casa por **classe de sintoma** (não
> string literal) — por isso cada entrada tem uma linha `tags:` com termos locale-independentes.
>
> **Depois de resolver um problema novo**, adicione uma entrada aqui (gate no `CHECKLIST_ENCERRAR_SESSAO`
> e no `/checkpoint`). Fonte da verdade = git; sincroniza pra todas as máquinas via `git pull`.
> Regra: **R23** (`01_REGRAS_INEGOCIAVEIS.md`).
>
> **Formato de cada entrada:** `## <sintoma curto>` · `tags:` · **Contexto** · **Causa raiz** ·
> **Solução** · **Ref**. Severidade implícita pela ordem (mais comum/caro primeiro).

---

## Índice

- [Conselho "revisa a coisa errada" / prompt stale entre runs](#conselho-prompt-stale)
- [Hook `.ps1` quebra com erro de parser / acento vira caractere estranho](#ps51-ascii-hooks)
- [Declarei versão errada ao retomar sessão (origin já estava à frente)](#origin-stale-resume)
- [Fix aplicado não funciona / hipótese de root cause estava errada](#reproduzir-antes-de-fixar)
- [Coach/projeto tentou commitar arquivo no canon (write cross-repo)](#cross-repo-write)

---

## Conselho "revisa a coisa errada" / prompt stale entre runs {#conselho-prompt-stale}

`tags: council, conselho, orchestrator, prompt stale, /tmp, arquivo fixo, windows path, revisa errado, repetido`

**Contexto:** ao rodar o `council-orchestrator` duas vezes seguidas, a 2ª rodada "revisa a pergunta
antiga" — o conselho responde sobre o prompt anterior, não o novo.

**Causa raiz:** command docs salvavam a pergunta num **nome de arquivo FIXO** (`/tmp/council-q.txt`).
No Windows `/tmp/...` resolve pra `d:\tmp\...`; se a 2ª escrita não sobrescreveu, o orchestrator leu o
prompt VELHO. NÃO era cache do orchestrator (ele lê `Get-Content -Raw` fresco) nem o
`prompt_cache_hit_tokens` da DeepSeek (red herring de cache de prefixo server-side).

**Solução:** arquivo temp **único por invocação** — `Join-Path $env:TEMP "council-q-$([guid]::NewGuid().ToString('N')).txt"`
(Windows) ou `mktemp` (Unix), escrito e consumido na mesma invocação, com cleanup. Idem pro
`-CrossClaudeFile`. Alternativa à prova de stale: passar o prompt por **stdin**. Corrigido em v6.16.1.

**Ref:** `CANON_VERSION.md` changelog v6.16.1; memória `project_council_stale_prompt_bug`.

---

## Hook `.ps1` quebra com erro de parser / acento vira caractere estranho {#ps51-ascii-hooks}

`tags: powershell, ps1, hook, parser error, encoding, cp1252, em-dash, emoji, acento, BOM, cmd`

**Contexto:** um hook `.ps1` do canon falha com erro de parse, ou strings com acento/emoji aparecem
corrompidas, **só quando rodado via `.cmd`** (não no pwsh direto).

**Causa raiz:** PowerShell 5.1 (invocado via `powershell.exe` dentro de um `.cmd`) lê `.ps1` **sem BOM**
como **cp1252**, não UTF-8. Em-dash (—), emoji ou qualquer não-ASCII num literal string quebra o parser.

**Solução:** mantenha os hooks `.ps1` do canon **100% ASCII** no código-fonte. Sem em-dash, sem emoji,
sem acento em string literal. Use `Voce`/`nao`/`-` em vez de `Você`/`não`/`—`. (Os system-prompts e
docs `.md` podem ter acento; a regra é só pros `.ps1` executados via `.cmd`/PS 5.1.)

**Ref:** memória `feedback_ps51_ascii_hooks`. Exemplo: os prompts inline do `council-orchestrator.ps1`
usam "Voce e revisor..." de propósito.

---

## Declarei versão errada ao retomar sessão (origin já estava à frente) {#origin-stale-resume}

`tags: git, origin, retomar, resume, versao, version, fetch, behind, stale local, declarar errado`

**Contexto:** ao retomar trabalho, declarei "estamos na vX.Y.Z" mas o `origin/main` já tinha uma versão
mais nova — trabalhei em cima de estado defasado.

**Causa raiz:** confiei no estado local sem comparar com o remoto.

**Solução:** **sempre `git fetch` + comparar com `origin/main`** antes de declarar versão/estado ou
retomar. Em projeto canon, ler `.percus-version` local **e** `origin/main:.percus-version`.

**Ref:** memória `feedback_check_origin_before_resume`.

---

## Fix aplicado não funciona / hipótese de root cause estava errada {#reproduzir-antes-de-fixar}

`tags: debug, root cause, hipotese errada, fix nao funciona, curl, argv, mangling, reproduzir, tooling`

**Contexto:** apliquei um fix baseado numa hipótese plausível e o problema continuou — a causa real era
outra. (Incidente v6.8.4: hipótese inicial "AGENTS.md em CP1252" estava parcialmente certa, mas o root
cause real — `curl` argv mangling — só apareceu rodando o script local de tooling.)

**Causa raiz:** declarar fix sem **reproduzir** o problema com a ferramenta real primeiro.

**Solução:** antes de declarar qualquer fix de tooling, **rode o script/comando que reproduz** o
problema localmente e confirme a causa observada — não a inferida. Reproduzir > teorizar.

**Ref:** memória `feedback_reproduce_tooling_before_fix`.

---

## Projeto tentou commitar arquivo no canon (write cross-repo) {#cross-repo-write}

`tags: cross-repo, canon, write, commit, outro projeto, protocolo, bloqueado, mover arquivo`

**Contexto:** um projeto (ex.: Coach) tentou escrever/commitar um arquivo dentro do canon
(`_Novo_Projeto`) ou o canon tentou `git mv/cp/rm` pra fora dele.

**Causa raiz:** violação do protocolo cross-repo. O canon **nunca escreve em outro repo** e nenhum
projeto escreve no canon diretamente.

**Solução:** o **único** mecanismo é entregar uma **caixa de texto pro operador colar manualmente** no
repo de destino. Leitura cross-repo é permitida; escrita não. Se precisa propagar algo do canon pra um
projeto (ou vice-versa), gere o bloco de texto e peça pro operador aplicar.

**Ref:** memória `feedback_cross_repo_write_protocol` (reforçado 2026-05-30).

---

> **Nova entrada?** Copie o bloco-modelo abaixo, preencha, e adicione no Índice.
>
> ```
> ## <sintoma curto> {#ancora-kebab}
> `tags: termo1, termo2, classe-de-erro, componente`
> **Contexto:** quando/onde aparece.
> **Causa raiz:** o porquê real (não o sintoma).
> **Solução:** o que fazer, com comando se aplicável.
> **Ref:** commit / memória / arquivo.
> ```
