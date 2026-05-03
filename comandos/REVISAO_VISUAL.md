---
tipo: comando-pronto
quando-usar: para auditar e priorizar revisão visual de telas usando v0.dev + shadcn MCP
nao-toca-codigo: true
leitura: 2 min
ultima-atualizacao: 2026-05-02
---

# Comando — Adicionar revisão visual com v0.dev + shadcn ao plano

> Cole o bloco abaixo no chat do agente em cada projeto onde quer fazer a revisão visual.
>
> **Requer R10 (design via v0.dev + shadcn MCP).** Detalhes do fluxo em `comandos/DESIGN_WORKFLOW.md`.

---

```
Preciso adicionar uma frente de revisão visual ao projeto usando v0.dev + shadcn (caminho oficial Percus pós-Fase 2 — R10).

Faça o seguinte, sem tocar em código:

1. Leia docs/PLANO.md e docs/mock-audit.md (se existirem)
2. Liste TODAS as telas/páginas visuais do projeto — inclua:
   - Telas já em [5-T] (funcionando) que podem estar visualmente defasadas
   - Telas em [4-C] ou abaixo que ainda vão ser implementadas
   - Landing page, login, dashboard, páginas institucionais
3. Para cada tela, classifique em uma destas 3 categorias:
   - 🎨 OK — visual atual é bom, não precisa revisão
   - 🎨? REVISAR — visual pode melhorar, gerar draft em v0.dev antes de mexer
   - 🎨!! URGENTE — visual claramente defasado/inconsistente, prioridade alta

4. Atualize docs/PLANO.md adicionando uma nova frente:

## Frente: Revisão Visual (v0.dev + shadcn)

- [0] 🎨!! {Tela urgente 1} — {motivo: inconsistência, defasagem, etc}
- [0] 🎨!! {Tela urgente 2}
- [0] 🎨?  {Tela a revisar 1}
- [0] 🎨?  {Tela a revisar 2}
- [-]     {Tela que está OK — não entra no plano de revisão}

5. Atualize HANDOFF.md com:
   - Nova seção "Revisão Visual Pendente" listando as telas 🎨!! e 🎨?
   - Próximo passo recomendado: qual tela atacar primeiro e por quê

6. Me devolva um RELATÓRIO curto (não código) com:
   - X telas 🎨!! urgentes
   - X telas 🎨? a revisar
   - X telas OK (pulam revisão)
   - Ordem sugerida de ataque (mais alto impacto primeiro)
   - Para a primeira tela da fila: prompt pronto para colar no v0.dev seguindo o template
     do `comandos/DESIGN_WORKFLOW.md` Caminho 2. Incluir:
       - Stack alvo (Vite+React 19+Tailwind 4+shadcn ou Next.js 15)
       - Comportamento esperado da tela
       - Componentes shadcn já presentes no repo
       - Restrições Percus (sem localStorage pra JWT, Zustand, react-hook-form+zod)
       - Referência visual se houver
   - Se a tela for componente isolado em vez de página inteira, sugerir Caminho 1
     (shadcn MCP via `npx shadcn@latest add <comp>`) em vez de v0.dev — economiza créditos

REGRAS:
- Não edite nenhum arquivo de código (.tsx, .ts, .css, etc)
- Só atualize docs/PLANO.md e HANDOFF.md
- Não inicie implementação de nenhuma tela — só classifica e planeja
- Se detectar tela 🎨!! que já está em [5-T], mantenha [5-T] mas marque 🎨!! para sinalizar que o visual precisa ser refeito mesmo funcionando
- NÃO sugerir Claude artifacts (claude.ai/design) como caminho — está vetado em R10 (disponibilidade instável bloqueava trabalho)
```

---

## Como usar

1. Abra cada projeto no Claude Code
2. Cole o bloco acima no chat
3. O agente vai auditar as telas, atualizar o PLANO e HANDOFF, e devolver o relatório
4. Pegue a primeira tela da fila:
   - **Página/fluxo novo** → cole o prompt sugerido no v0.dev (browser, créditos Vercel próprios)
   - **Componente isolado** → rode `npx shadcn@latest add <componente>` direto no projeto
5. Código aprovado → volta ao Claude Code → integra seguindo `[1-S]→[5-T]`
6. Antes de declarar a tela em `[5-T]`: rodar `/percus-review:review` (R11)

---

## Referências cruzadas

- Workflow detalhado de design: `comandos/DESIGN_WORKFLOW.md`
- Regra (gate lexical): `01_REGRAS_INEGOCIAVEIS.md` R10
- Review cross-provider obrigatório por marco: R11 (`/percus-review:milestone-review --base <commit>`)
