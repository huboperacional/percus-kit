## Gate escapado 80 vezes em 30 dias não é indisciplina — é regex errado pra código em português {#gate-escapado-em-massa-e-regex-errado}

tags: MOCK-OK toda hora, mock-scan bloqueia sempre, TODO em portugues, gate que ninguem respeita, escape reincidente, 21 escapes num dia, R3 falso positivo, gate treina o operador a escapar, drift de gate, palavra portuguesa casa marcador

**Sintoma.** Todo commit que toca um arquivo grande é barrado pelo `mock-scan`, e a mensagem
precisa começar com `MOCK-OK: <motivo>`. Você escreve o motivo, passa, e segue. Semanas depois, a
contagem: **80 escapes em 30 dias, com pico de 21 num único dia.**

**Como medir (2 comandos).**
```bash
git log --since="30 days ago" --format="%s" | grep -ci "MOCK-OK"
git log --since="30 days ago" --format="%ad|%s" --date=short | grep -i "|MOCK-OK" \
  | cut -d'|' -f1 | sort | uniq -c | sort -rn | head
```

**Causa raiz.** O padrão do gate procura `TODO/FIXME/XXX/HACK`, e **`TODO` é palavra comum em
português** — *"faz TODO chamador quebrar alto"*, *"depois de TODO resumo de carrinho"*, *"reprovava
TODO endereço"*. Num repositório com comentários em PT-BR ela aparece às dezenas por arquivo. O gate
não está pegando marcador pendente: está pegando prosa.

**Por que isso é pior que um falso positivo comum.** O gate de mock/placeholder existe pra impedir
que código provisório chegue em produção (R3). Um gate que dispara em toda prosa **treina o operador
a escapar por reflexo** — e no dia em que houver um `TODO:` de verdade, o `MOCK-OK` vai junto, sem
ninguém ler. O valor do gate não cai devagar: ele vira zero.

**A regra que aplica aqui** (loop `drift`): estourar **uma vez** é descuido; estourar **quatro** não
é o operador — é o desenho. **Proponha a partição, não mais disciplina.**

**Correção.** Exigir marcador de verdade em vez da palavra solta: `TODO:` / `TODO(` / `# TODO` /
`// TODO`, com dois-pontos, parêntese ou início-de-comentário obrigatórios. Um `\bTODO\b` casa
português; um `\bTODO\s*[:(]` não.

**Enquanto não corrigir**, duas armadilhas ligadas: o prefixo `MOCK-OK:` **só é lido dentro de
`-m`** (com `-F -`/heredoc o hook não enxerga o argumento), e o `PreToolUse` bloqueia o comando
INTEIRO — `git add && git commit` encadeado nunca chega a fazer o `add`. Ver
`{#pretooluse-bloqueia-comando-inteiro-add-nao-roda}`.

**Ref:** tiatendo, 30 dias até 2026-08-12 — 80 escapes, 6 deles numa sessão só.
