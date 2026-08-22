## Migrar para um resolvedor COMUM troca a direção do casamento em silêncio — contenção (`texto in rótulo`) não é o mesmo que menção (rótulo dentro da frase) {#resolvedor-comum-troca-a-direcao-do-casamento-em-silencio}

`tags: consolidacao, resolvedor comum, matcher, contencao, substring, mencao, palavra inteira, migracao, regressao silenciosa, capacidade perdida, escolha por nome, fronteira do modulo, FR-C1`

**Sintoma:** você consolida N sítios num módulo de escolha único. Os testes do módulo passam, os do
sítio passam, e um teste de corpus antigo reprova dizendo que responder pelo NOME parou de funcionar.
Parece fixture velho. Não é: a migração **trocou o matcher**, e ninguém escreveu isso em lugar nenhum.

**Contexto (Família Milionária, Fase 3, 2026-08-21):** o módulo comum casava nome assim —

```python
casados = [i for i, r in enumerate(rotulos)
           if normalizarTexto(r) == t or t in normalizarTexto(r)]   # CONTENÇÃO
```

…isto é, **o texto digitado tem de caber DENTRO do rótulo**. O sítio migrado usava outra coisa:

```python
gate._mencionaDescricao(texto, descricao)   # MENÇÃO: as palavras do rótulo aparecem na FRASE
```

As duas direções coincidem quando a pessoa responde exatamente o rótulo (`"Spotify"`). Divergem no
caso real: **`"o spotify"` é MAIOR que `Spotify`**, então a contenção falha e a menção acerta. Como
usuário de bot responde frase, não etiqueta, a migração regrediria em silêncio uma capacidade
documentada meses antes — e o único sinal foi um teste de corpus.

**Por que passa despercebido:** os testes do módulo comum usam rótulos curtos e respostas exatas
(`"conta 2"` contra o rótulo `conta 2`), onde as duas direções dão o mesmo resultado. A divergência
só aparece com frase natural, que é justamente o que a suíte do módulo não tem.

**A saída, e ela é de FRONTEIRA, não de matcher:** o que o módulo comum não resolve, o **sítio**
resolve **antes** — o mesmo padrão que já valia para os `extras` (`"todas"`). Concretamente, o sítio
converte a menção em índice e só então chama o resolvedor:

```python
if estado.get("aceitaNome") and not texto.isdigit():
    casados = [i for i, item in enumerate(itens, 1)
               if gate._mencionaDescricao(texto, item["descricao"])]
    if len(casados) == 1:          # N candidatos NÃO escolhem
        texto = str(casados[0])
r = resolverEscolha(texto, estado, agora=utcNow())
```

**Por que NÃO alargar o resolvedor comum:** ele já servia cinco sítios migrados, todos em caminho de
ESCRITA. Aceitar a direção nova lá dentro mudaria o casamento de nome dos cinco de uma vez —
entradas que hoje são `NAO_ENTENDI` passariam a ESCOLHER, sem pedido, sem medição e sem review. A
mudança de raio de um matcher de escrita é decisão à parte, não efeito colateral de refatoração.

**Regra prática, aplicável a qualquer consolidação:** antes de trocar um sítio para o matcher comum,
escreva a pergunta em voz alta — *"o que o usuário digita CABE no rótulo, ou o rótulo aparece no que
ele digita?"* Se a resposta for a segunda, o módulo comum não serve sozinho, e o conserto é a
fronteira (resolver antes), não afrouxar o módulo.

Ver também [[alargar-matcher-de-guarda-troca-miss-por-alvo-errado]] e
[[trava-por-substring-aceita-mencao]].
