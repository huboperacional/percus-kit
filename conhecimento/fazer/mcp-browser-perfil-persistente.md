## Antes de construir andaime de login, veja se o MCP de browser já está logado {#mcp-browser-perfil-persistente}
`tags: chrome-devtools-mcp, playwright-mcp, sessao, autenticacao, perfil persistente, list_pages, OTP, magic-link, E2E, captura de tela`

**Quando:** você precisa navegar num app autenticado (o seu ou o de um concorrente) para capturar telas
ou exercitar fluxo, e o login é OTP/2FA — ou seja, "depende do operador".

**Passos:**
1. `list_pages` → se aparecer `about:blank`, o MCP subiu um Chrome **próprio**, não anexou ao teu.
2. **Mesmo assim, navegue para o app antes de concluir que não há sessão.** O Chrome do MCP costuma
   usar um **perfil persistente** — os cookies de sessões anteriores do operador podem estar lá.
3. O sinal de sucesso é a **URL final**: se `https://app/` redirecionou para `/dashboard` em vez de
   `/login`, a sessão está viva. Um snapshot que mostra o shell do app confirma.
4. Só se cair no `/login` monte o andaime (magic-link server-side, seed de org descartável, etc.).

**Comando:** `list_pages` → `navigate_page(url)` → conferir a URL devolvida.

**Armadilhas:** o caminho contrário custou caro numa sessão — eu já tinha lido o runbook de magic-link,
localizado o script, e estava a um passo de mintar credencial em produção para uma identidade
**adivinhada por e-mail** (o que criaria identidade nova em vez de logar como a pessoa). Duas
navegações resolveram o que o andaime não resolveria. Corolário: **org descartável semeada não serve
para revisão de densidade/estética** — tela vazia dá leitura falsa; para julgar layout você precisa da
org real, com dado real.

**Ref:** Plexco Tasks s156 (deep-dive ClickUp × Plexco, 28 capturas em 2 produtos autenticados).
