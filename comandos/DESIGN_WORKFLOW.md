---
tipo: comando-pronto
quando-usar: pedido visual detectado (R10 + G0 do checklist) — antes de codar qualquer coisa visual
nao-toca-codigo: false (gera código real via shadcn/v0)
leitura: 4 min
ultima-atualizacao: 2026-05-01
---

# Design Workflow — v0.dev + shadcn MCP (substitui Claude artifacts)

> **Por que existe:** Claude artifacts (claude.ai/design) fica indisponível ~6/7 dias por semana e bloqueia trabalho visual. Este documento define o caminho oficial Percus que **não depende** dele.

---

## Princípio

Cada tipo de pedido visual tem uma ferramenta correta. Não trate todos como "preciso de mockup" genérico.

| Tipo | Ferramenta | Por quê |
|---|---|---|
| Componente isolado (button, card, modal, form, table) | **shadcn MCP** | Adiciona via CLI direto no repo Vite/Next; código pronto, padrão Percus (Tailwind 4 + shadcn) |
| Tela nova / fluxo novo, alta fidelidade | **v0.dev** | Browser próprio Vercel, créditos próprios, exporta React/Tailwind alinhado ao stack Percus |
| Iteração sobre tela existente | Edição local + `npm run dev` | A própria tela é o feedback loop — não precisa mockup |
| Diagrama / wireframe / arquitetura | **Excalidraw** ou **Mermaid** em markdown | Versionável, sem dependência externa, abre no Claude Code |
| Rascunho descartável quando Claude artifacts está disponível | Claude artifacts | OK pra brainstorm visual rápido, **não** pra produção |

---

## Caminho 1 — Componente isolado (shadcn MCP)

**Quando usar:** "preciso de um modal de confirmação", "adiciona um data table", "queria um command palette", "form de login".

### Passos

1. Confirme com usuário qual componente shadcn cobre o pedido. Se não souber, liste opções:
   ```
   /shadcn list
   ```
2. Adicione no projeto:
   ```
   /shadcn add <componente>
   ```
   ou via CLI direta:
   ```bash
   npx shadcn@latest add <componente>
   ```
3. Posicione o componente no fluxo de telas conforme o uso.
4. Personalize via Tailwind/variants — **não** modifique o código fonte do shadcn instalado a menos que seja de propósito (sem perder rastro).
5. Siga o fluxo `[0]→[5-T]` normal a partir daqui.

**Custo Claude:** baixíssimo. A skill `vercel:shadcn` faz a chamada local; Claude só orquestra.

---

## Caminho 2 — Tela nova / fluxo novo (v0.dev)

**Quando usar:** "landing page do produto X", "dashboard de métricas", "fluxo de onboarding em 3 passos", "redesign da home".

### Passos

1. **Pare antes de codar.** Confirme com usuário que vai usar v0.dev:
   > Vou abrir o caminho v0.dev pra essa tela. Te entrego o prompt pronto pra você colar lá; quando aprovar o resultado no v0, me manda o código exportado e eu integro no projeto seguindo `[0]→[5-T]`.

2. **Monte o prompt v0.dev** com:
   - Stack alvo (`Vite 6 + React 19 + Tailwind 4 + shadcn/ui` por padrão, ou `Next.js 15` se for landing pública)
   - Descrição do que a tela faz (não só visual — comportamento)
   - Componentes shadcn que já existem no projeto (se aplicável)
   - Restrições Percus relevantes (ex.: "auth via JWT em cookie httpOnly", "estado leve com Zustand", "sem localStorage")
   - Referência visual se houver (link, descrição de estilo)

3. **Entregue o prompt ao usuário** num bloco copiável. Espere ele iterar no v0.dev e te trazer o código aprovado.

4. **Integre o código** no projeto:
   - Crie a rota/página correspondente (TanStack Router ou App Router conforme stack)
   - Adapte imports pra estrutura de pastas Percus
   - Substitua dados mock do v0 por dados reais do backend (R3: nada de mock escondido)
   - Adicione tracking conforme `03_TRACKING_ATTRIBUITION.md` se for página pública

5. Siga `[0]→[5-T]` normal.

**Custo Claude:** zero durante a fase v0 (usuário gasta créditos Vercel). Claude só entra na integração.

### Template de prompt v0.dev

```
Crie uma <tipo de tela> para um <produto X>.

Stack: Vite 6 + React 19 + TypeScript 5 + Tailwind 4 + shadcn/ui
(ou: Next.js 15 App Router se for landing pública)

Comportamento:
- <o que a tela faz, fluxos>
- <interações esperadas>

Componentes shadcn já disponíveis no repo:
- <lista>

Restrições:
- Sem localStorage para JWT
- Estado client com Zustand (não Redux)
- Forms com react-hook-form + zod
- <outras restrições do produto>

Referência visual:
- <link / descrição>

Não inclua dados mock — me deixa placeholders óbvios para eu plugar no backend depois.
```

---

## Caminho 3 — Iteração sobre tela existente

**Quando usar:** "mexe no header pra...", "ajusta espaçamento do card", "muda a cor do CTA".

### Passos

Sem mockup. Sem v0. Sem shadcn (a menos que falte componente):

1. Edita direto, recarrega `npm run dev`, vê na tela.
2. Faz commit pequeno por mudança.
3. `/percus-review:review` antes do commit (R11 normal).

---

## Caminho 4 — Diagrama / wireframe

**Quando usar:** explicar arquitetura, mostrar fluxo de dados, esboçar layout antes de qualquer código.

### Opções

- **Mermaid** em `.md` — diagrama de fluxo, sequência, ER. Renderiza no Claude Code preview, no GitHub, no Obsidian.
- **Excalidraw** — `.excalidraw` ou `.excalidraw.svg` no repo. Editor nativo no VS Code via extensão.

Sem ferramenta externa, sem custo Claude além de gerar o markdown/svg.

---

## Quando usar Claude artifacts (exceção)

**Apenas quando:**
- Está disponível no momento (raro, ~1/7 dias)
- E é rascunho descartável de brainstorm visual
- E você não vai colar o código direto em produção

**Nunca como caminho oficial.** Se travou esperando Claude artifacts voltar, você está violando R10 — mude pra v0.dev.

---

## Checklist de saída

Antes de declarar "tela pronta":

- [ ] Stack do código gerado bate com o stack Percus do projeto (Vite ou Next conforme `02_INFRA_E_STACK_PERCUS.md` 5.1)
- [ ] Sem dados mock escondidos (R3 — banner MODO DEMO se ainda não conectou backend)
- [ ] Componentes shadcn estão na pasta correta do projeto, não importados de pacote externo
- [ ] `/percus-review:review` passou (R11)
- [ ] Tela aparece no fluxo navegacional (rota registrada)

---

## Anti-padrões

- ❌ Tentar abrir Claude artifacts e travar quando estiver indisponível, em vez de usar v0.dev
- ❌ Pedir pro Claude "gerar HTML/JSX da tela do zero" quando shadcn ou v0 cobrem
- ❌ Copiar código do v0 mantendo dados mock — vira bug de demo (R3)
- ❌ Adicionar shadcn como **pacote** (`npm install @shadcn/...`) — shadcn é "copiar pro repo", não dependência
- ❌ Usar v0.dev pra componente isolado que shadcn já tem — desperdiça créditos Vercel
