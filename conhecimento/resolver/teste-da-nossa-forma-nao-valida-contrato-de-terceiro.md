## Teste que confere a forma que NÓS montamos não valida contrato de terceiro {#teste-da-nossa-forma-nao-valida-contrato-de-terceiro}

`tags: teste, mock, api externa, contrato, smoke, 5-T, assercao vazia, meta ads, graph api, R23`

**Sintoma:** a suíte está verde, o payload é exatamente o que o código pretende montar — e a API
externa **recusa a chamada**. O teste não estava errado sobre o código; estava errado sobre o que
prova. Ele afirma *"montamos o campo X"* e é lido como *"a API aceita o que montamos"*, que é outra
coisa.

**Reprodução real** (Paid Media Automation, 2026-09-09, criação de campanha no Meta): o criativo
gravava `lead_gen_form_id` em **dois lugares** — como chave direta de `link_data` e dentro de
`call_to_action.value`. O teste era:

```ts
expect(criativoBody).toContain('"lead_gen_form_id":"form42"');
```

Verde. E a Meta recusava o criativo inteiro:

> *O campo `lead_gen_form_id` não é permitido no campo `link_data` de `object_story_spec`*

A asserção é **vazia para esse defeito**: `toContain` é satisfeito pelo lugar certo, pelo errado, e
pelos dois ao mesmo tempo. Conferir que a string **aparece** não é conferir que ela aparece **no
lugar certo**.

Na rodada seguinte, o mesmo smoke achou a segunda regra que nenhum teste pegaria: a Meta **exige
`link`** mesmo em anúncio de formulário instantâneo, onde a pessoa nunca sai da plataforma e o link
não leva a lugar nenhum. Duas exigências da API, uma por rodada, nenhuma dedutível do nosso código.

**Por que nenhuma quantidade de teste unitário resolve:** o mock devolve o que você mandou ele
devolver. Um mock construído a partir da sua própria leitura da documentação reproduz a sua
leitura, inclusive quando ela está errada — é a família do *mock espelha o bug*. O contrato mora no
servidor do terceiro, e só a chamada real o consulta.

**O que fazer:**

1. **Trate `[5-T]` contra a API real como parte da entrega, não como conferência final.** Onde o
   código fala com terceiro, "suíte verde" prova ausência de regressão nossa, nunca aceitação dele.
2. **Depois que a API recusar, transforme a regra aprendida em gate que afirma o LUGAR**, não a
   presença. No caso acima, parseando a estrutura e afirmando as duas metades:
   ```ts
   const spec = JSON.parse(new URLSearchParams(body).get("object_story_spec") ?? "{}");
   expect(spec.link_data.call_to_action.value.lead_gen_form_id).toBe("form42");
   expect(spec.link_data).not.toHaveProperty("lead_gen_form_id"); // a metade que faltava
   ```
3. **Veja o gate reprovando com o defeito reintroduzido.** Um gate escrito depois do conserto tende
   a nascer moldado pelo conserto e passar por vacuidade.
4. **Escreva no comentário de onde veio a regra** — "medido em produção, a Meta recusa com
   `<mensagem>`". Sem isso, o próximo leitor acha que a linha é zelo e a "simplifica".

**Sinal de que você está nessa armadilha:** a asserção usa `toContain`, `toMatch` ou
`expect.stringContaining` sobre um corpo serializado. Isso testa *substring*, e substring não tem
posição na estrutura. Se o campo tem lugar, o teste tem que ter caminho.

Relacionado: [[gate-que-nunca-foi-visto-reprovando-aprova-tudo]].
