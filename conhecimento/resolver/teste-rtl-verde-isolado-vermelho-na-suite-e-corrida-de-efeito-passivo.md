## Teste RTL verde isolado e vermelho só na suíte cheia é corrida de efeito passivo — ancore a espera no estado FINAL da tela {#teste-rtl-verde-isolado-vermelho-na-suite-e-corrida-de-efeito-passivo}

`tags: vitest, testing-library, react, flaky, findBy, waitFor, useEffect, efeito passivo, corrida, suite, jsdom, R23`

**Sintoma:** testes RTL/Vitest falham ~1 em 3 rodadas da suíte COMPLETA e nunca isolados, e o
conjunto de falhas muda a cada rodada. Medido em 30/08/2026 no Paid Media Automation: um teste via
`decisions.marker` sair `undefined` depois de digitar num input; outro via a tela dizer "Nenhum
estágio mensurável" com o fetch já resolvido.

**Causa raiz:** React 18/19 adia efeitos passivos (`useEffect`) para DEPOIS do commit — e
`findBy*`/`waitFor` resolvem no commit, ANTES de os efeitos rodarem. Um teste que age nessa janela
(digitar, ler a lista) interage com estado que o efeito ainda vai apagar ou completar
(`setFields({})` de um efeito de sugestão; `setPipelineAberto(primeiro)` de um efeito de abertura).
Sob a carga de workers paralelos a janela alarga o bastante para o teste entrar nela; isolado,
nunca. Na tela real a janela é um frame — dedo humano não alcança: **o defeito é do arranjo do
teste, não do componente.**

**Correção:** a espera do teste ancora no estado FINAL visível da tela, nunca em "o fetch foi
chamado" nem em "o loading sumiu":

```ts
// antes de digitar: espere o que a RESPOSTA renderiza
await screen.findByText("sem sugestão");
// antes de ler a lista: espere a lista EXISTIR
await waitFor(() => expect(screen.getAllByRole("checkbox").length).toBeGreaterThan(0));
```

**Armadilhas adjacentes:**
- Aumentar timeout às cegas NÃO conserta (a corrida é de ordem, não de tempo) e mascara travamento
  real. Exceção legítima: gate que faz I/O pesado de verdade (varredura síncrona de `src/` inteiro)
  merece `{ timeout: N }` próprio e comentado — sob carga ele passa de 5s honestamente.
- Diagnóstico rápido: rode o arquivo isolado; verde isolado + vermelho na suíte + falhas migrando
  entre rodadas = esta classe, não bug de produto.

Caso completo: commit `202fe434` do Paid Media Automation (3 arquivos, 2 corridas + 1 timeout;
suíte 491 arquivos/4347 testes 2× verde depois).
