# Handoff Consumidores — o que mudou da 6.57 à 6.62.2 e como conferir o seu projeto

> **Para:** a sessão Claude de qualquer projeto Percus.
> **De:** canon Percus `percus-kit` **v6.62.3**, a versão que publica este handoff (só documentação). Cobre as
> mudanças da 6.57.0 à 6.62.2 (`D:\Claud Automations\percus-kit\CANON_VERSION.md`).
> **Data:** 2026-09-17. **Antes deste:** `HANDOFF_CONSUMIDORES_v6.56.md` (R11 com retry e `registrar-review`), que continua valendo.

Não mude código do produto por causa deste documento. Ele pede conferências e, no máximo, texto no
`CLAUDE.md`/`AGENTS.md` e hook git. Commit e push seguem as regras de sempre (R11, R20).

---

## 1. O que mudou para um projeto (5 minutos)

| Versão | Mudança | O que muda no seu trabalho |
|---|---|---|
| 6.57.0 | **Checkpoint e sessão nova são só do operador.** O `context-budget-guard` só informa. | Nunca inicie checkpoint nem mande abrir sessão nova por conta própria. No máximo cite o número de contexto uma vez. |
| 6.58.0 | **Trilhos P / M / G (R9).** P = mexe no que existe, até ~5 arquivos; M = feature nova ou muda o que é gravado; G = schema, auth, pagamento, integração que envia/cobra/publica, segredo, tracking, hook/canon, deploy. | Declare o trilho e a estimativa na primeira resposta; nunca rebaixe. P/M: plano curto, uma revisão por lote, no máximo 2 rodadas de conserto, sem marco nem `✓`, sem conselho automático, R11 com `-NoFactCheck`. Só G tem marco, `milestone-review` e conselho automático. Uma frente por sessão. |
| 6.58.0 | **`UI-verified`** para mudança que não grava dado (forma visual do R1). | Trailer `UI-verified: YYYY-MM-DD HH:MM` (com hora). Só data volta a avisar desde a 6.59.0. |
| 6.59.0 | `registrar-review` captura a saída; chave de API fora da linha de comando do `curl`. | Nada a fazer. |
| 6.60.0 | **R11 fatiado** acima de 1.500 linhas de diff. | Ao chamar a review, use timeout **600000**. |
| 6.61.0 | **ADR por 4 perguntas** (basta um "sim"): outro projeto precisa mudar código; quebra contrato/API consumido de fora; muda de forma irreversível dado já gravado; deixa dívida registrada com dono. **N/A escrito** nos checklists de feature. | Item pulado de checklist vira `N/A: <motivo>`. Sem nenhum "sim", é changelog e commit, não ADR. |
| 6.62.0 | **Push em duas camadas (R20).** Guard do Claude Code + hook git `pre-push`. | **Todo push exige autorização prévia** (ver §3). `--no-verify` e troca de `core.hooksPath` bloqueiam sempre. |
| 6.62.0 | **Gate V2 julga só o que o commit muda.** `.ps1` com acento sem BOM bloqueia no commit. | O escape `PERCUS_GATE_OVERSIZE` deixa de ser rotina: use só com motivo real do próprio commit. |
| 6.62.0 | Checklist de feature: G2 ganha **Alcance** e **Grade de QA** (visual, segurança, performance, mobile 390 px, regressão). | Vale no M com tela e no G. P fica fora. |
| 6.62.x | Suíte e guard do kit. | Nada a fazer. |

## 2. Confira no seu projeto (uma linha de resposta por item)

Rode da raiz do projeto, com `git -C "<caminho absoluto>"`. Só leitura, salvo onde está escrito "corrija".

1. **Versão adotada.** Leia `.percus-version`. Relate o valor. Não altere só por este handoff; ele sobe
   quando o projeto passar pelo `D:\Claud Automations\percus-kit\comandos\REORGANIZAR_PROJETO.md`.
2. **Hook `pre-push` instalado.** A pasta de hooks é a de `git -C "<raiz>" config --get core.hooksPath`
   (rode sozinho, numa chamada) ou, sem valor, `.git/hooks`. Confira se existe `pre-push` ali (Glob, não
   `ls` com redirecionamento — o guard barra).
   - **Existe:** `sha256sum` do arquivo, numa chamada só. Esperado:
     `a43302fa6bb2600835cac85a64ae0611582a99d219851123f2c35ce76800dfbf`.
   - **Não existe — corrija:** numa chamada sozinha da ferramenta Bash, sem `;`/`&&`/redirecionamento:
     `sh "D:/Claud Automations/percus-kit/plugin/percus-review/git-hooks/instalar-pre-push.sh" "<raiz do projeto>"`.
     Depois `sha256sum` e `sh -n` em chamadas separadas. Instalado em 19 projetos em 2026-09-16/17.
3. **Hook `pre-commit`.** Relate qual tipo tem: com marcadores `=== PERCUS-MERGED-HOOK BEGIN ===` (R11
   nativo), só `# --- percus-v2-gate ---` (gate V2) ou híbrido legado v5.0.8. **Não edite à mão** — o guard
   barra escrita em `.git/hooks`, e atualizar exige decisão do operador.
4. **`CLAUDE.md` com os trilhos.** Procure a frase "Trilhos P e M — este arquivo tem precedência sobre as
   skills upstream". **Ausente — corrija** pelo PASSO 2 do `REORGANIZAR_PROJETO.md` (copiar esse bloco, "Uma
   frente por sessão", a linha "Spec ou plano do trilho G" do roteador e o "Critério de pronto" com
   `UI-verified`, de `D:\Claud Automations\percus-kit\templates\CLAUDE.template.md`). No `AGENTS.md`, as
   linhas R1 e R9 de `templates\AGENTS.template.md`. Sem isso as skills upstream mandam no trilho P/M.
5. **Checkpoint antigo no texto do projeto.** Procure em `CLAUDE.md`, `AGENTS.md` e `HANDOFF.md`:
   "checkpoint ao fim de milestone", "RESET OBRIGATÓRIO", "Hora de checkpoint". **Achou — corrija** para:
   checkpoint só quando o operador pedir.
6. **Autorização de push.** Confira se `.percus/` está no `.gitignore` (a autorização e a auditoria não
   devem ser commitadas). Relate sim/não.

## 3. Push a partir de agora

1. O operador autoriza **na conversa**.
2. A sessão cria a autorização (ferramenta PowerShell, nunca Bash):
   `& 'D:\Claud Automations\percus-kit\scripts\autorizar-acao-externa.ps1' -Motivo '<o que sobe>' -ProjetoRoot '<raiz absoluta do repo>'`.
   Vale 60 min. Em worktree, a raiz é a do checkout principal.
3. Push na forma simples, sozinho numa chamada: `git -C "<raiz absoluta>" push`.
4. O hook grava a auditoria em `.percus\autorizacoes-usadas.jsonl`. Push barrado: leia a mensagem e peça
   autorização. Nunca edite, remova ou desvie o hook.

## 4. Formato do retorno ao operador

```
Projeto: <nome> | .percus-version: <x> | pre-push: ok/instalado/divergente | pre-commit: R11/V2/legado
CLAUDE.md trilhos: ok/corrigido | checkpoint antigo: nenhum/corrigido | .percus no .gitignore: sim/não
Commit pendente: <arquivos alterados, sem commit feito> | Bloqueios: <nenhum ou qual>
```
