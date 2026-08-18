## Guard test que proíbe um vocabulário legado (regex `\bword\b`) colide com nome novo legítimo que contém a mesma palavra {#guard-legado-word-boundary-colide-nome-novo}

`tags: guard test, regex word boundary, nome de modulo, migration, vocabulario proibido, colisao de nome`

**Contexto:** um recurso foi removido de um projeto (ex.: uma migration dropou uma tabela) e ganhou
um guard test que faz `re.search(rf"\b{palavra}\b", linha)` sobre o código-fonte inteiro, pra
garantir que o modelo removido nunca "volte por dentro" — prática comum depois de um bug real em
produção causado por aquele modelo. Meses depois, uma feature NOVA e legitimamente diferente
precisa de um nome que contém a mesma palavra (ex.: a tabela nova é `tenant_funnel_steps`, o
modelo antigo removido era `funnel_steps`).

**Sintoma:** a suíte de testes falha só quando o nome aparece como PALAVRA INTEIRA cercada por
não-palavra (espaço, ponto, aspas, início/fim de string, hífen em rota HTTP) — não quando aparece
como substring dentro de outro identificador. Isso produz uma colisão que parece arbitrária: um
nome de MÓDULO Python bare (`import funnel_steps`) quebra o guard; o nome da TABELA
(`tenant_funnel_steps`, prefixado por `_`) não quebra, porque `\b` não bate entre dois caracteres
de palavra (`_` conta como `\w`). Rota HTTP com hífen (`/funnel-steps`) quebra por CHECAGEM DE
SUBSTRING simples (`"/funnel-steps" in path`), não regex — mecanismo diferente, mesmo efeito.

**Causa raiz:** o guard é literal (protege a STRING, não o conceito), e isso é uma escolha
DELIBERADA do autor original (ver docstring do guard: "o grep não distingue comentário de SQL, e
essa ambiguidade é o ponto: o nome não deve sobreviver em lugar nenhum") — não é um bug do guard,
é o comportamento pretendido. O bug, se houver, é do lado de quem escreve o nome novo sem saber que
esse guard existe.

**Solução:** antes de nomear um módulo/rota/chave de payload novo que ecoa um conceito antigo já
removido do projeto, rodar `grep -rn "test_.*legacy\|test_.*removed\|proibid" tests/` (ou equivalente)
pra achar guards desse tipo ANTES de escrever código. Se colidir: prefixar com algo que quebre o
word-boundary na posição que importa (`custom_`, `tenant_`, um domínio diferente) — funciona porque
`_` e letras adjacentes não criam boundary pra `\b`, mas TABELA/coluna de banco já prefixada
(`tenant_x`) costuma escapar sozinha; o que geralmente precisa de rename é o símbolo Python/rota
HTTP que usa o nome BARE. Rodar a suíte INTEIRA (não só o arquivo novo) depois de qualquer rename —
é a única forma confiável de confirmar que o guard passou, porque ele varre a árvore inteira.

**Ref:** Paid Media Automation, sessão 2026-08-06 (cont.154) — módulo/rota `funnel_steps` colidiu
com `test_funnel_legacy_removed.py` (guard da migration 0028, que removeu a tabela `funnel_steps`
original); renomeado pra `custom_funnel_steps` em módulo Python, rota HTTP, chave de payload JSON e
tipo TypeScript — a tabela nova `tenant_funnel_steps` não precisou renomear.
