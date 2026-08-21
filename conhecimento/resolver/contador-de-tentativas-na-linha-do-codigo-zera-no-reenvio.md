## Contador de tentativas guardado na linha do código zera a cada reenvio — e o limite não vale nada {#contador-de-tentativas-na-linha-do-codigo-zera-no-reenvio}

`tags: codigo de confirmacao, otp, forca bruta, rate limit, tentativas, reenvio, postgres, indice parcial, 2fa, aceite`

**Sintoma:** nenhum. O código diz "5 tentativas", o comentário diz "5 tentativas", a documentação diz "5 tentativas" — e um bot consegue tentar quantas vezes quiser. Nada falha, nada loga, nada aparece em teste.

**Causa raiz:** o desenho natural é `codigo_confirmacao(id, codigo_hash, expira_em, tentativas)`, com o contador na linha do código. Reenviar apaga o código anterior e insere outro — e o contador vai embora com a linha.

Se **reenviar não tem limite**, o atacante pede código novo, chuta 5, pede de novo. Sobre um espaço de 1.000.000 de códigos de 6 dígitos, chutes ilimitados em lotes de 5 são chutes ilimitados.

🔑 **A conta que revela o buraco:** limite por código × reenvios ilimitados = limite infinito. Se o contador vive no que é descartado, ele não é um contador.

**Solução:**

1. **Não apague o código anterior — descarte.** Coluna `descartado_em timestamptz`, e o `UPDATE` no lugar do `DELETE`:
   ```sql
   UPDATE codigo SET descartado_em = now()
    WHERE alvo_id = $1 AND usado_em IS NULL AND descartado_em IS NULL;
   ```
   A linha fica, com os chutes que levou.
2. **O limite passa a somar o alvo inteiro**, não a linha:
   ```sql
   SELECT coalesce(sum(tentativas), 0) FROM codigo WHERE alvo_id = $1;
   ```
3. **Limite o reenvio também.** Sem isso, sobra o outro abuso: encher a caixa de entrada de quem não pediu, e a tabela junto.
4. **Índice único parcial** garante um código pendente por vez, sem janela de corrida:
   ```sql
   CREATE UNIQUE INDEX codigo_um_valido ON codigo (alvo_id)
     WHERE usado_em IS NULL AND descartado_em IS NULL;
   ```
   Com ele, o `SELECT ... FOR UPDATE` na única linha pendente serializa dois chutes simultâneos — e a soma feita depois, no mesmo `READ COMMITTED`, enxerga o incremento já commitado do outro.

⚠️ **Quando o limite esgotar, recuse o reenvio também.** Recusar só o chute deixa a porta aberta: pedir código novo sem limite é o que zerava tudo em primeiro lugar.

**Como testar sem esperar 10 chutes:** leve o contador ao limite pelo banco (`UPDATE codigo SET tentativas = 9`) e faça os dois últimos pela interface. Prova a borda em dois cliques em vez de dez.
