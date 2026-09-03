## Coluna nova no `SELECT` morre em silêncio se a função projeta um dict literal {#coluna-nova-no-select-morre-na-projecao-literal}

`tags: sql, projecao, dict literal, RowMapping, coluna nova, correcao inerte, no-op silencioso, spec, gate de saida, R23`

**Sintoma:** você acrescenta uma coluna ao `SELECT` de uma função de leitura, usa o campo no
consumidor, a suíte fica verde, o deploy sobe — e **a mudança não faz nada**. Nenhum erro, nenhum
`KeyError`, nenhum teste vermelho. O comportamento antigo continua, e ninguém descobre até o efeito
que a mudança deveria produzir faltar em produção.

**Causa raiz:** a função **não devolve as linhas do banco**. Entre o `SELECT` e o retorno existe uma
**projeção** — um `dict` literal com chaves fixas, montado à mão:

```python
item = {
    "platform_campaign_id": r["platform_campaign_id"],
    "name": r["name"],
    "currency_code": r["currency_code"],
    ...
}
```

Sem `**r`, a coluna nova **morre ali**. E o consumidor, se lê com `.get()`, recebe `None` sem
reclamar. O defeito é invisível dos dois lados: o SQL está certo, o consumidor está certo, e o meio
descarta.

🔑 **Por que a suíte não pega:** os testes usam fábrica de linha falsa, e linha falsa construída à
mão **sempre traz a chave**. Ela testa o consumidor, nunca a projeção. Todo teste unitário do
consumidor passa com a projeção quebrada.

**Como resolver:** um gate que afirma **as duas pontas no mesmo teste** —

```python
assert "caa.active" in sql                     # a coluna está no SELECT
assert linha["account_active"] is not None      # e chegou na saída da projeção
```

Este é o padrão que fecha o buraco, e ele independe de banco real: a entrada pode ser sintética
(é o que o Postgres devolveria), porque a asserção é sobre a **saída da projeção**, que é onde o
defeito mora.

⚠️ **Não caia na tentação de exigir Postgres real no gate.** Costuma ser inexecutável — a função
qualifica tabelas de outro serviço (`public.x`), que as fixtures daquela suíte não criam, e
`search_path` não alcança nome qualificado. Gate inexecutável somado a consumidor que lê com
`.get()` é a receita do no-op verde.

**Como detectar antes de escrever a spec:** ao planejar "acrescentar campo X ao SELECT", rastreie o
campo **do `SELECT` até o consumidor** e conte os pontos. Se houver projeção no meio, são **três**
pontos, não dois — e o do meio é o único que falha calado.

Relacionado: [[401-em-wrapper-que-herda-env-nao-prova-nada-sobre-a-chave]]
