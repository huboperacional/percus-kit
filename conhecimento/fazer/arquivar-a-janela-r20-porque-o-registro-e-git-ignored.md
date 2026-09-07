## Arquive toda janela R20 ao consumi-la — o registro vive em `.percus/`, que é git-ignored {#arquivar-a-janela-r20-porque-o-registro-e-git-ignored}

`tags: R20, acao-externa-autorizada.json, .percus, gitignore, rastreabilidade, cadeia de autorizacao, docs/historico, arquivo unico compartilhado, evidencia, duas janelas no mesmo dia, R11`

**Quando:** sempre que uma janela R20 for consumida — no mesmo passo em que você marca `consumido: true`, antes do teardown terminar.

**Por que:** `.percus/acao-externa-autorizada.json` é **arquivo único, compartilhado e git-ignored** (o `.gitignore` traz o comentário do porquê: commitado, viraria bypass permanente do guard para todo mundo). Duas consequências que só aparecem depois:

1. **A próxima janela sobrescreve a sua e o registro some para sempre.** Não há histórico no git para recuperar.
2. **A evidência que você commita fica órfã da autorização.** Você escreve *"medido na janela R20 de 07/09"* e o repositório não contém nenhuma janela — ou pior, contém só a de outra hora, dizendo que aquele item **não** entrou nela.

O caso medido: numa mesma sessão houve **duas** janelas no mesmo dia. A primeira ficou arquivada e declarava, corretamente para ela, *"o relatório PIX não entrou nesta janela"*. A segunda — que consumiu o relatório — vivia só em `.percus/`. O R11 pegou: *"o leitor não consegue distinguir entre uma segunda janela não registrada e um relato incorreto"*. Procede, e o buraco é impossível de fechar depois, porque o arquivo já teria sido sobrescrito.

**Como fazer:**

```bash
# 1. LEIA antes de gravar a sua -- `consumido: false` = janela VIVA de outra sessao
cat .percus/acao-externa-autorizada.json

# 2. Se for sobrescrever, ARQUIVE a entrada anterior primeiro (nao a sua: a que esta la)
cp .percus/acao-externa-autorizada.json \
   docs/historico/<data>-r20-<escopo-da-anterior>-consumida.json

# 3. Ao FECHAR a sua, arquive a sua tambem -- com teardown ja medido dentro
cp .percus/acao-externa-autorizada.json \
   docs/historico/<data>-r20-<seu-escopo>-consumida.json
```

E **cite o arquivo na evidência**, pelo caminho: `docs/historico/<...>.json`. Havendo mais de uma janela no dia, cite as duas **lado a lado**, dizendo o que cada uma consumiu — é isso que impede a leitura errada.

**O que NÃO fazer:** editar o arquivo já arquivado para "corrigir" o que ele diz. Ele é um retrato daquele momento e vale por ser fiel; o conserto é arquivar a janela seguinte e referenciar as duas, nunca reescrever a primeira.

**Ref:** 2026-09-07, Empresa Milionária — achado do R11 sobre o próprio diff do checkpoint, aplicado antes do commit. Relacionado: [[guard-de-acao-externa-casa-o-motivo-nao-a-acao]] e [[arquivo-untracked-engana-a-ferramenta-que-le-o-indice]] — a mesma família de "o git não vê, então a ferramenta conclui errado".
