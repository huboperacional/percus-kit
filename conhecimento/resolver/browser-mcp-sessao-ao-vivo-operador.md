## Browser MCP (Playwright/Chrome-DevTools) pode estar conectado a um perfil Chrome REAL com sessão AO VIVO do operador, não um perfil isolado {#browser-mcp-sessao-ao-vivo-operador}

`tags: playwright mcp, chrome-devtools mcp, browser automation, profile compartilhado, sessão ao vivo, e2e produção, campo preenchido sozinho, navegação inesperada, concorrência humano-agente`

**Contexto:** verificando visualmente uma feature web em produção via `browser_navigate`/
`browser_snapshot` do Playwright MCP (ou chrome-devtools MCP), depois de um dos dois servidores
desconectar e liberar um lock de `userDataDir` que os dois disputavam.

**Sintoma:** `browser_navigate` pra uma rota autenticada abre DIRETO numa sessão já logada (nome,
dados reais do usuário visíveis) — sem o agente ter feito login. Ao reabrir um form pra completar a
verificação (ex.: reabrir um modal "Novo item"), os campos vêm **preenchidos com dado que o agente
não digitou**, e a página navega sozinha pra outra rota sem nenhuma chamada `browser_navigate` do
agente.

**Causa raiz:** o MCP de browser não estava apontando pra um perfil `--isolated`/efêmero — estava
conectado ao perfil Chrome PESSOAL do operador (o mesmo que ele usa no dia a dia), que já tinha uma
sessão autenticada viva. O operador estava usando o app **em paralelo**, na mesma aba/perfil que o
agente estava controlando via automação. Login sem interação do agente, campo preenchido do nada e
navegação não solicitada são os 3 sinais de que isso está acontecendo — não é bug do MCP, é
compartilhamento genuíno de sessão com um humano.

**Por que é perigoso:** cliques/navegação do agente competem com a interação real da pessoa —
podem sobrescrever o que ela estava digitando, navegar pra longe da tela em que ela estava
trabalhando, ou (pior) o agente poderia clicar "Salvar"/"Criar" em cima de dado que não é seu,
submetendo algo indesejado numa conta de produção real. Categoria de risco distinta de
[Duas sessões Claude no MESMO diretório colidem](sessoes-paralelas-mesmo-diretorio-colidem.md) — ali
é agente-vs-agente; aqui é agente-vs-humano-real-usando-o-produto.

**Solução / como aplicar:**
1. Antes de clicar/preencher/submeter qualquer coisa, `browser_snapshot` primeiro. Se algum campo já
   tiver texto que você não colocou lá, ou se você chegou autenticado sem ter feito login, TRATE
   como sessão possivelmente compartilhada.
2. Prefira uma leitura passiva (abrir modal só pra conferir estrutura, sem submeter) pra confirmar
   UI; só avance pra CRUD ativo (criar/editar/deletar) com alta confiança de que é seguro — ou numa
   sessão que você sabe que é isolada.
3. Ao detectar sinal de atividade concorrente, PARE imediatamente. Não tente "consertar" clicando em
   Cancelar repetidamente (isso também é uma ação na sessão de outra pessoa) — avise o operador
   direto e peça pra ele confirmar que nada ficou fora do lugar do lado dele.
4. Se a config do MCP permitir `--isolated`/um `userDataDir` próprio, prefira isso pra qualquer
   verificação automatizada de UI — evita a classe inteira do problema.

**Ref:** Família Milionária, sessão 2026-08-07 — verificação da feature Metas/Desejos (`/metas`);
Chrome-DevTools MCP desconectou, Playwright MCP assumiu o mesmo perfil e caiu numa sessão real do
operador (campo "Evelyn"/"Evelyn IPTU" preenchido sozinho, navegação pra `/dividas` não solicitada).
Agente parou antes de submeter qualquer coisa; operador confirmou que nada ficou fora do lugar.
