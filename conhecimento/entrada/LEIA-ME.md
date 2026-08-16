# Caixa de entrada de conhecimento

Escreva aqui **um arquivo por verbete**. Não edite `COMO_RESOLVER.md` / `COMO_FAZER.md` direto.

```
resolver/<slug>.md   -> vai pro COMO_RESOLVER.md   (problema -> solução)
fazer/<slug>.md      -> vai pro COMO_FAZER.md      (procedimento-base)
```

O **nome do arquivo é o slug** da âncora (`## Título {#slug}`). O gate barra se divergir — é o que
torna o merge determinístico e o split futuro mecânico.

Conteúdo é o formato de sempre: `## Título {#slug}` · `tags:` · corpo · `**Ref:**`.
Sem linha de índice: o mesclador insere sozinho.

## Por que a caixa existe

`COMO_RESOLVER.md` tem centenas de verbetes num arquivo só, e toda sessão de todo projeto escreve
nele. O git resolve conflito em **arquivo**, então duas sessões escrevendo lições sobre assuntos
completamente diferentes colidiam assim mesmo. Medido em 2026-08-16: um commit levaria junto o
rascunho inacabado de outra sessão, e o gate barrou o commit legítimo.

Arquivos separados não colidem. O merge vira ato único, no `checkpoint`.

## Como sai daqui

`scripts/mesclar-conhecimento.ps1`, rodado pelo `checkpoint`. Se ele disser **ADIA**, outra sessão
está com o monólito aberto e as entradas esperam o próximo checkpoint — adiar é de graça, porque a
caixa é durável. Ver R23 em `01_REGRAS_INEGOCIAVEIS.md`.
