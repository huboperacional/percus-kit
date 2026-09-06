## `COUNT`/`MAX` agregado no PAI colapsa "filho ausente" e "filho presente com zero" — e a mensagem fica tecnicamente verdadeira e inútil {#agregado-no-pai-esconde-a-ausencia-do-filho}

`tags: agregacao, count, max, lateral join, evidencia, mensagem de alerta, ausencia, verdade por omissao, granularidade, alerta acionavel, R23`

**Sintoma:** um alerta descreve o estado com um número agregado e o número está **certo**, mas
quem lê tira a conclusão errada — e ninguém percebe porque não há nada de falso na frase.

**Caso real (Paid Media Automation, 06/09/2026).** O vigia de conta lia, por CLIENTE:

```sql
SELECT count(*) AS linhas, MAX(md.spend) AS gasto_maximo
  FROM metrics_daily md JOIN client_ad_accounts ca ON ca.id = md.ad_account_id
 WHERE ca.client_id = c.id AND ca.active AND md.date = :dia
```

O cliente tinha **duas** contas: a Google reportou 1 linha com gasto 0, e a Meta — a que gastava
R$ 36-59/dia — **sumiu da coleta**. O agregado deu `linhas=1, gasto_maximo=0`, e a mensagem saiu:

> "1 linha(s) de métrica em 05/09, nenhuma com gasto > 0"

Verdade absoluta. E indistinguível de um cliente com **uma** conta só que reportou zero. O operador
recebeu isso por dois dias e não tinha como saber que a conta que sustentava a receita tinha
evaporado.

**Causa:** `count(*)` e `MAX()` sobre filhos colapsam a diferença entre **"filho não apareceu"** e
**"filho apareceu com zero"**. São fatos de naturezas opostas — um é sobre o dado, o outro é sobre
o sujeito — e a agregação é justamente a operação que os torna iguais.

🔑 **A regra:** quando a decisão é sobre AUSÊNCIA, a evidência tem de ser da granularidade em que a
ausência acontece. Se o predicado varre filhos, a mensagem lista filhos:

```
CA - Moper Ecommerce (META 631349538569890) — SEM LINHA em 05/09 (última linha: 31/08/2026)
Moper ( Grupo ) (GOOGLE 2560302158) — 1 linha(s) em 05/09, gasto máximo 0.00
```

⚠️ **A data da última ocorrência é o que transforma "sumiu" em "sumiu QUANDO"** — e é ela que torna
o alerta acionável. Sem ela o leitor não distingue "nunca reportou" (conta nova, provavelmente
cadastro errado) de "reportava e parou em 31/08" (evento a investigar). Custo medido: um
`MAX(date)` por filho com índice `(pai_id, date DESC)` deu **0,066 ms e 7 buffers** numa tabela
particionada por mês — é barato, não é motivo para agregar.

⚠️ **Não jogue fora o agregado ao adicionar o detalhe.** Se a evidência é persistida (aqui, JSONB
em `client_account_watch.evidence`), linhas antigas não têm os campos novos: mantenha o ramo
antigo do formatador vivo e ligue o novo por presença de chave (`if any("linhas" in c ...)`).
Formatador que quebra em cima do próprio histórico cala o alerta **no dia do deploy**.

**Onde procurar isto no seu código:** todo `count(*)`/`MAX`/`SUM` sobre filhos cujo resultado
alimenta uma decisão de "não teve nada". Pergunte: *se um filho sumisse, este número mudaria de um
jeito distinguível de um filho ter reportado zero?* Se não, a mensagem vai mentir por omissão.

Relacionado: [[controle-positivo-por-dominio-de-falha-do-medidor]],
[[absence_design_loss]], [[empty_state_must_name_scope]].
