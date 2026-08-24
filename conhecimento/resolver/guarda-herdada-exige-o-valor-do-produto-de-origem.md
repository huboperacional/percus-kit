## Guarda herdada pode EXIGIR o valor do produto de origem {#guarda-herdada-exige-o-valor-do-produto-de-origem}

`tags: fork, derivacao, produto de origem, preco, teste herdado, assert que afirma o defeito, suite verde mentirosa, fonte da verdade, catalogo, vacuidade, prompt`

**Sintoma:** você acha um dado do **produto de origem** vivo no código derivado — preço, nome,
percentual, URL — e pergunta *"tem teste cobrindo isso?"*. Tem. Está verde. **E é ele que mantém o
defeito vivo**, porque o assert **afirma** o valor herdado.

**Caso medido (Empresa Milionária, 2026-08-24).** O `PRODUCT_FACTS`, injetado no prompt do bot em
toda conversa, informava ao cliente PJ:

```
- Planos: Mensal R$19,90 | Anual R$167,16 (30% OFF — equivale a R$13,93/mês)
```

A tabela de **pessoa física** do produto de origem — enquanto `app/core/planos.py` documentava
exatamente isso na **primeira linha**. A guarda que existia:

```python
def test_product_facts_inclui_planos():
    assert "19,90" in facts or "167,16" in facts or "mensal" in facts.lower()
```

Verde, e **exigindo** o preço errado. Corrigir o valor sem corrigir o teste deixa a suíte vermelha,
o que empurra a próxima sessão a "consertar" o teste de volta para o valor herdado.

**Causa raiz:** o fork copiou **código e suíte**. O teste foi escrito quando `19,90` era correto, e
continua correto no produto de origem — ninguém o reescreveu ao derivar. Não é teste ruim: é teste
**de outro produto**.

**Detecção — antes de corrigir, grep o valor nos TESTES:**

```bash
rg "19,90|167,16" tests/     # o valor herdado está sendo AFIRMADO em algum lugar?
```

Se estiver, os dois mudam no **mesmo commit**.

**Conserto que impede reincidência — derive, não digite.** O valor passou a ser montado a partir da
fonte da verdade:

```python
def _linhaDePlanos() -> str:
    assert PLANOS_VENDAVEIS, "catálogo sem plano vendável"
    return " | ".join(
        f"{p.rotulo} R${_reais(p.precoCentavos)}/mês (de R${_reais(p.precoTabelaCentavos)})"
        for p in PLANOS_VENDAVEIS
    )
```

Preço muda por decisão comercial, e **string literal em prompt é onde ninguém procura** quando muda.
A asserção nova compara com o catálogo, não com outro literal.

🪤 **Três armadilhas ao reescrever a guarda:**

1. **Vacuidade.** `for p in PLANOS_VENDAVEIS: assert ...` passa se a lista esvaziar. Ponha
   `assert PLANOS_VENDAVEIS` antes.
2. **Vitrine ≠ catálogo.** Só o recorte vendável vira oferta; planos que existem para ancorar preço
   não podem aparecer numa mensagem ao cliente.
3. **Ler não é vender.** Preço de plano **aposentado** precisa continuar sendo lido pelo valor
   contratado — uma varredura que trate toda ocorrência do preço velho como defeito apaga o que
   sustenta o contrato de quem paga.

**Onde procurar o resto:** o mesmo valor costuma estar em mais de uma superfície. Depois do prompt,
apareceu em 12 mensagens automáticas de trial, no menu de planos do onboarding, no re-prompt
escalonado e no prompt de uma segunda IA — além de um percentual de comissão de afiliado que
contradizia a página pública do próprio produto. Ordene por **alcance**: o texto chega ao cliente?

Parente de [[teste-passa-em-cima-do-defeito]] — lá o teste **escapa** do defeito pelo exemplo
escolhido; aqui ele o **exige** pelo assert. Ver também [[mecanismo-armado-nao-prova-disparo]] para
não confundir "existe no código" com "chega ao cliente".
