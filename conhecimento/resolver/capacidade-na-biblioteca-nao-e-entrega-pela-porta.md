## Capacidade na biblioteca não é entrega pela porta do produto {#capacidade-na-biblioteca-nao-e-entrega-pela-porta}

`tags: fiacao, transporte, rota http, biblioteca, feature invisivel, dois executores, payload, R23`

**Sintoma:** a feature está implementada, testada, revisada e com todos os gates verdes — e o
produto continua se comportando exatamente como antes. Ninguém mente no relatório: a biblioteca
**sabe** fazer. O que ninguém verificou é se existe caminho da porta de entrada até ela.

**Reprodução real** (Paid Media Automation, 2026-09-09): uma fase inteira ensinou
`createMetaCampaignStack` a gravar `url_tags` (a UTM), `destination_type`, `promoted_object`,
`lead_gen_form_id`, idioma, posicionamento e N conjuntos. Suíte verde, review limpa, tudo
integrado. Depois, um grep de 10 segundos na rota HTTP:

```bash
for c in destinationType promotedObject leadGenFormId adsets locales publisherPlatforms urlTags; do
  grep -c "$c" web/src/app/api/mutations/route.ts
done
# 0 0 0 0 0 0 0
```

A rota montava o input **campo a campo**, à mão, e não passava nenhum deles. Pior: o `ad` só
aceitava `creativeId` (reusar criativo), e a UTM só é gravada no ramo que **cria** criativo — então
**campanha criada pelo produto continuava nascendo sem rastreamento**, que era exatamente o defeito
que a fase existia para corrigir.

**Por que passa despercebido:** os testes da biblioteca chamam a biblioteca. Os testes da rota
mockam a biblioteca e conferem que ela foi chamada. Nenhum dos dois pergunta *"com quê?"*. O buraco
mora entre as duas suítes, que é onde ninguém olha porque cada lado está verde.

**O que fazer:**

1. **O gate tem que exercitar o caminho que a UI chama.** Testar só o tradutor prova que a tradução
   funciona, sem provar que alguém a chama — que é precisamente o buraco.
   ```ts
   const input = mocks.createMetaCampaignStack.mock.calls[0][0];
   expect(input.adset.destinationType).toBe("ON_AD");   // atravessou a rota
   ```
2. **Ao fechar qualquer fase que estende uma biblioteca, faça o grep dos nomes novos na porta de
   entrada.** Custa segundos e responde "isto é alcançável?".
3. **Quando há mais de um executor do mesmo pedido, o mapeamento é UM só.** No caso acima, propor
   (`POST /api/mutations`) e aprovar (`/api/mutations/[id]/approve`) montavam o input cada um por
   si — mapeamento duplicado **diverge em silêncio**: um lado ganha campo novo, o outro não, e a
   campanha aprovada sai diferente da proposta, sem erro em lugar nenhum. Extraia uma função
   compartilhada e faça as duas passarem por ela.
4. **Cuidado com o campo que só existe num ramo.** Aqui `url_tags` era escrito apenas quando o
   criativo era criado por nós; como a rota só oferecia o ramo de reuso, o campo era inalcançável
   por construção. Pergunte, para cada campo novo: *em qual ramo ele é escrito, e a porta oferece
   esse ramo?*

**Sinal de alerta:** um relatório de fase que diz "implementado, testado, integrado" sem citar
nenhuma chamada real pela porta do produto. "Endpoint respondendo 200" e "biblioteca com teste
verde" são a mesma classe de prova incompleta.

Relacionado: [[teste-da-nossa-forma-nao-valida-contrato-de-terceiro]].
