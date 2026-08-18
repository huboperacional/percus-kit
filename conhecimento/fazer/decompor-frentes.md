## Decompor trabalho grande em frentes {#decompor-frentes}

`tags: frentes, decompor, cascata, retomada, contexto, checkpoint, paralelismo, worktree, plano`

**Quando:** um milestone/épico grande demais pra tocar numa aba só, ou que gargala na retomada de sessão.

**Passos:**
1. **Precisa só retomar barato** (perder menos contexto entre sessões)? Já é nativo: escreva o estado em
   frentes no `templates/PLANO.template.md` (frente é conceito de 1ª classe lá) + use a skill `checkpoint` e o
   hook PreCompact (v6.19). Não crie estrutura de arquivos nova.
2. **As frentes são genuinamente independentes e você quer rodá-las em paralelo** (2-4 abas, wall-clock)?
   Use `comandos/COMANDO_FRENTES_PARALELAS.md` (worktrees + aba-diretora + writer-unique). Requer fundação
   `[5-T]` merged antes.
3. **Nenhum dos dois** (é serial e cabe numa aba)? Fluxo normal (`feature-flow`), sem cerimônia.

**Armadilhas:** **não** invente um mecanismo "cascata" separado (arquivos aninhados
`docs/plans/<milestone>/<frente>.md` com métrica de retomada) — foi avaliado e **aposentado na v6.27.0**:
o eixo retomada já é checkpoint/PreCompact, o eixo decomposição já é o `PLANO.template`, e o paralelismo
é o `COMANDO_FRENTES_PARALELAS`. Reintroduzir seria duplicar (viola R25).

**Ref:** `CANON_VERSION.md` changelog v6.27.0; `comandos/COMANDO_FRENTES_PARALELAS.md`; skill `checkpoint`.
