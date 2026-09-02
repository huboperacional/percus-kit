## Migration precisa de `BEGIN/COMMIT`, e o teste que executa o `.sql` não pode executar o `COMMIT` {#migration-com-begin-e-o-teste-que-executa-o-sql}

`tags: migration, postgres, teste, transacao, producao, gate, R23`

**Os dois lados desta regra se contradizem se você resolver um de cada vez.** Resolva juntos.

### Lado 1 — a migration PRECISA do par

Aplicar migration com `psql -f arquivo.sql` **sem** `--single-transaction` faz cada comando
commitar sozinho. Numa migration que troca uma constraint:

```sql
ALTER TABLE t DROP CONSTRAINT c_check;
ALTER TABLE t ADD  CONSTRAINT c_check CHECK (...);
```

existe uma janela entre os dois em que a tabela fica **sem constraint nenhuma** — pior que o estado
antigo e que o novo. Se o `ADD` falhar (lock, conexão caindo, operador interrompendo), a tabela fica
permanentemente sem a guarda. Com um escritor rodando 24/7, isso é buraco de verdade.

⇒ Envolva em `BEGIN;` / `COMMIT;`.

### Lado 2 — mas aí o TESTE que lê o arquivo passa a commitar contra produção

O padrão de "provar a migration contra o Postgres real" é abrir uma transação com o driver, executar
o texto do `.sql`, asserir, e fazer `rollback()`. Ao adicionar `BEGIN/COMMIT` ao arquivo, o `COMMIT;`
lido de dentro dele **commita a transação do teste**. E o pior não é o commit: é que **as asserções
continuam passando**, porque um `down` bem escrito já reverteu o schema e apagou as linhas por conta
própria. O teste reporta verde depois de ter destruído dado real.

### Correção — exigir o par e REMOVÊ-LO antes de executar

Um helper resolve os dois lados de uma vez:

```python
def _corpo_sem_transacao(caminho: Path) -> str:
    texto = caminho.read_text(encoding="utf-8")
    corpo = "\n".join(
        l for l in texto.splitlines() if not l.strip().startswith("--")
    ).strip()
    assert corpo.count("BEGIN;") == 1 and corpo.count("COMMIT;") == 1
    assert corpo.upper().startswith("BEGIN;")
    assert corpo.upper().rstrip().endswith("COMMIT;")
    return corpo[len("BEGIN;") : corpo.rstrip().rfind("COMMIT;")]
```

Ele vira **gate de produção** (a migration não pode perder o par sem o teste reprovar) **e**
proteção do próprio teste (quem manda na transação é o driver, não o texto do `.sql`). A checagem de
**unicidade** não é zelo: o recorte usa `rfind`, então um comentário inline ou literal contendo a
palavra `COMMIT` cortaria o corpo no lugar errado e o teste passaria a executar SQL truncado sem
acusar nada.

### O resto do cinto de segurança, quando o alvo é produção

- **Opt-in por variável, passada como PREFIXO da invocação, nunca `export`.** Um `export` deixa a
  env viva no shell e a próxima varredura de testes dispara o destrutivo sozinha.
- **Recusar autocommit** (`assert conn.autocommit is False`) — sem transação não há o que desfazer.
- **Medir o rollback, não confiar nele**: fotografe a contagem antes, faça `rollback()` explícito no
  fim e asserte que voltou. Em MVCC, linha apagada por ESTA transação volta a ser visível quando ela
  é desfeita, inclusive linha que outra transação havia commitado — mas isso se mede, não se supõe.
- **`statement_timeout` e `lock_timeout` na conexão do teste.** Sem eles, um comando que trava
  segurando `ACCESS EXCLUSIVE` deixa a tabela em fila — medido em 2026-09-02: uma sonda pendurou uma
  transação por 583s e as limpezas seguintes ficaram esperando atrás dela.

### `down` de migration que alarga um domínio não é simétrico

`DROP CONSTRAINT` + `ADD CONSTRAINT` mais estreito **falha** se já existirem linhas do valor novo. O
`down` tem de apagar essas linhas ANTES de reapertar. E, como isso destrói dado coletado, vale dizer
no próprio arquivo que **o rollback de imagem provavelmente não precisa dele**: alargar um CHECK é
retrocompatível — o código antigo não escreve o valor novo e não se importa com o domínio largo.
