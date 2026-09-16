# Catálogo de artefatos e jornadas — referência do MDS

> **Isto é REFERÊNCIA consultável, não obrigação.** Nenhuma linha aqui vira checklist bloqueante,
> nenhum hook trava por causa deste arquivo, e nada aqui exige produzir um documento novo. Use as
> listas abaixo quando quiser conferir cobertura ("criei todas as automações? todos os
> papéis/permissões?") ou precisar de um formato leve pra descrever uma função operacional — nada
> além disso. **Não adotamos** a "Família de 5" documentos por feature do MDS (decisão do
> operador, Fase 4, 2026-09-16); só as duas taxonomias abaixo entram, como material de consulta.

**Origem:** relatorio `mds-leitura-profunda-11-documentos.md` (estudo dos 11 documentos MDS, 2026-09-12), na
pasta de planos da maquina do operador — fora deste repositorio. Os numeros de linha citados abaixo sao
desse relatorio.
(relatório de leitura funda do MDS — Modular Development Style), seções 9 (linhas 529-551) e 10
(linhas 555-587).

## (a) Catálogo de tipos de artefato — 29 tipos em 9 famílias

Do documento "Inventário de Artefatos" do MDS (referência: relatório MDS, linhas 535-547).
Taxonomia de "coisas que um sistema pode ter" — útil como checklist de completude ao revisar um
projeto, não como formulário a preencher.

| Família | Tipos de artefato |
|---|---|
| Captura e dados | formulário, campo personalizado, entidade/tabela, etiqueta, segmento |
| Fluxo e processo | funil/pipeline, automação/workflow, cron/agendado, máquina de estados |
| Comunicação | template de mensagem, notificação, documento/PDF |
| Interface | tela/página, calendário/agenda, menu/navegação |
| Análise | dashboard, métrica/indicador, conector de dados |
| Integração e infraestrutura | API/webhook, variável de ambiente, serviço/container, migração de dados |
| Acesso e governança | papel/permissão, auditoria/log |
| Negócio | produto/plano, configuração de pagamento |
| Conteúdo e configuração | página/landing, asset de mídia, parâmetro de configuração/regra de runtime |

Uso sugerido: ao revisar um projeto ou planejar um marco, passar os olhos pela lista e perguntar
"tem algum tipo aqui que o projeto precisa e ainda não foi considerado?" — nada mais formal que
isso. Não vira card, não vira código `ART-*`, não é rastreado em lugar nenhum do canon.

## (b) Formato de jornada — 3 campos

Do documento "Jornadas dos Atores" do MDS (referência: relatório MDS, linhas 561-585). Formato
minimalista pra descrever uma função operacional do dia a dia, mais leve que uma spec ou um bloco
de atores completo — útil quando você só precisa deixar escrito "como essa função funciona" sem
abrir um artefato novo.

- **Como entra** (gatilho) — o que dispara essa função.
- **Onde entra** (tela, funil, sistema, canal) — em que lugar a ação acontece.
- **O que faz** (ações concretas e resultado) — o que a pessoa/sistema faz e o que resulta.

Exemplo (reproduzido do relatório MDS, linhas 570-585):

```
## Atendimento (pré-venda)

### Triagem de leads novos
- Como entra: um lead novo cai no funil por integração de fonte.
- Onde entra: a caixa de conversas e o funil comercial.
- O que faz: abre o lead, faz o primeiro contato e qualifica,
  aplicando as tags de origem e tipo.
```

Uso sugerido: descrever uma função operacional em texto solto (chat, PLANO, comentário), nos 3
campos acima. Não é documento formal, não tem template `.md` próprio, não substitui a spec do
trilho G.

## O que não entra aqui

Os outros 3 companheiros da "Família de 5" do MDS (DRS, Roadmap, Plano de Testes) **não** foram
adotados nem como referência — o kit segue a direção oposta (dono único por artefato, tamanho é
contrato; ver `01_REGRAS_INEGOCIAVEIS.md` e `v2/CONSTITUICAO.md`). Só as duas taxonomias acima
atravessaram o crivo: catálogo de tipos e formato de jornada são listas, não processo, e não
competem com nenhum artefato que o V2 já define.
