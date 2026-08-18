## Rodar checkpoint no próprio percus-kit (canon/tooling, sem PLANO/HANDOFF) {#checkpoint-no-canon-tooling}

`tags: checkpoint, percus-kit, canon, tooling, PLANO.md, HANDOFF.md, resume prompt, clear, compact`

**Quando:** a skill `percus-review:checkpoint` é disparada dentro do próprio repo `percus-kit`
(não num projeto-produto que consome o canon).

**Passos:**
1. **Não procure `docs/PLANO.md`/`HANDOFF.md`/`docs/mock-audit.md` na raiz** — não existem aqui
   de propósito. O hook `SessionStart` do próprio kit já declara isso: "Se eh canon/lib/tooling,
   ignore" o gate de HANDOFF/PLANO. Confirme com `Test-Path`/`ls` antes de assumir drift.
2. O equivalente de "PLANO" aqui é a seção `## ESTADO DA EXECUÇÃO` dentro do
   `docs/superpowers/plans/<data>-<tema>.md` de cada iniciativa em andamento — sincronize essa
   seção, não um PLANO.md inexistente.
3. Capture conhecimento novo (R23) escrevendo um arquivo por verbete em
   `conhecimento/resolver/<slug>.md` (ou `conhecimento/fazer/<slug>.md`), e regere o indice
   com `scripts/gerar-indice-conhecimento.ps1`.
4. Commit com review (R11) normalmente.
5. O "prompt de retomada" do passo 4 do checkpoint ainda se aplica — só troca "RELEIA PRIMEIRO:
   HANDOFF.md → docs/PLANO.md" pelos planos/branches relevantes da sessão (com caminho absoluto).

**Armadilhas:** tratar a ausência de PLANO/HANDOFF como um problema a corrigir (criar os arquivos
"pra seguir o padrão") — é o oposto do que o hook e a Constituição pedem pro kit em si.

**Ref:** `.claude/settings.json` do próprio kit (hook `SessionStart` `[GATE INICIO]`, que declara
a exceção "Se eh canon/lib/tooling, ignore").
