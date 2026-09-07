## O arquivo concatenado é o que embarca — editar os fontes ao lado não muda nada, e o comentário manda editar os fontes {#o-arquivo-concatenado-e-o-que-embarca}

`tags: css, design tokens, panelkit, tailwind, duplicacao, fonte morta, rebrand invisivel, comentario mentiroso, import, turbopack`

**Origem:** CL_Liliflow, 2026-09-07, durante a troca de marca HOPE → Liliflow.

**Sintoma.** Troquei os 6 tokens de accent em `components/panelkit/tokens/colors.css`, rodei build e
testes, tudo verde — e a interface continuaria laranja em produção. Nada acusa.

**Causa raiz.** `app/globals.css` importa **um só** arquivo:

```css
@import "../components/panelkit/tokens/styles.css";
@import "tailwindcss";
```

E `styles.css` **não** encadeia os outros: ele é uma **concatenação** dos 7 arquivos de token, feita
em algum momento para contornar dois problemas reais (o `@import` do Tailwind v4 é diretiva de
compilador e invalida `@import`s posicionados depois dele; e o bundler não resolvia a cadeia
multi-hop de forma confiável). Os 7 arquivos originais continuam no repositório, versionados,
editáveis — e **nunca carregados**.

O agravante estava no cabeçalho do próprio `styles.css`:

> *"Content below is copied verbatim from the 7 token files; edit token VALUES in those files, not here."*

Exatamente ao contrário. Quem seguisse a instrução faria um rebranding que não chega ao browser.

**Solução.** Alterar o valor **no arquivo concatenado** e espelhar no fonte, e corrigir o cabeçalho
para dizer qual dos dois embarca. Depois:

```sh
grep -rn "f97316\|ea580c" app components --include="*.css" --include="*.tsx"
```

- **O que o grep de hex NÃO pega:** sombras em `rgba()`. `--shadow-accent: 0 6px 18px rgba(236,48,19,.28)`
  sobreviveu a todas as buscas por hex e deixou um brilho laranja embaixo do botão primário roxo.
  Só apareceu na **captura de tela**. Mudança visual se verifica olhando, não com `grep` e teste.
- **Sinal genérico:** quando dois arquivos têm o mesmo conteúdo e um comentário explica qual editar,
  confirme **qual é importado** antes de acreditar. `grep -rn "@import" na entrada do CSS` responde
  em um segundo.
- **Cor de erro herdada do accent:** a regra mono-accent do kit (`--danger: var(--accent-press)`)
  funcionava com accent laranja, porque tom quente já lê como aviso. Com accent roxo, erro roxo não
  lê como erro. Ao trocar a marca para uma cor fria, `--danger` precisa deixar de ser alias.

**Ref:** `CL_Liliflow/app/components/panelkit/tokens/styles.css` (cabeçalho corrigido),
`app/globals.css` (única linha de import), `design/panelkit_design_system/`.
