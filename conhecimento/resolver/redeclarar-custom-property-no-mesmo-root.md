## Redeclarar custom property CSS no mesmo `:root` sobrescreve — e nenhuma ferramenta pega {#redeclarar-custom-property-no-mesmo-root}

`tags: CSS, custom property, :root, design system, shadcn, hsl(var()), token duplicado, computed value, cor transparente, build verde`

**Classe de sintoma:** ao adicionar tokens de um design system novo a um projeto que já tem outro
(shadcn, por exemplo), uma cor some ou vira transparente em telas que não foram tocadas. `tsc`,
suíte de testes e `build` passam todos.

**O mecanismo:** duas declarações da mesma custom property no mesmo seletor — a segunda vence. Se o
vocabulário antigo consome via função (`hsl(var(--accent))`) e o valor novo é hex, o resultado é
`hsl(#013A6F)`, **inválido**. Custom property inválida em computed-value-time faz a propriedade cair
no valor inicial: `background-color` vira `transparent`. A tela quebra em runtime de browser, que é
o único lugar onde a suíte não olha.

**Como evitar, antes de escrever:** grep pelo nome do token no arquivo de destino. Se já existir,
escolha outro nome — não "melhore" o valor existente.

**Como travar a regressão:** um guard que só confere **presença textual** do token antigo NÃO pega
isso (o nome continua lá, sobrescrito). O guard precisa afirmar o **formato do valor**, por exemplo
`/--accent:\s*\d+\s+\d+%\s+\d+%/` para garantir que continua HSL e não virou hex.

**Sinal de alerta correlato:** se o Tailwind já reserva o nome (`accent` → `accent-color`), o token
novo precisa de outro nome no config também.

**Ref:** Micro Investors, 2026-08-18, execução subagent-driven do Base UI. O defeito estava no
**plano**, não na implementação — o revisor pegou lendo o arquivo, não rodando nada. 3 telas de
Settings usavam `bg-accent`. Relacionado: `comentario-justificativa-verificavel`.
