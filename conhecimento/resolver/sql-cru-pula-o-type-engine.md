## SQL cru pula o type engine, e aí o DRIVER decide o tipo — teste verde, produção diferente {#sql-cru-pula-o-type-engine}

tags: sqlalchemy, text(), sql cru, type engine, sqlite vs postgres, uuid sem hifen, datetime naive vs aware, timezone=True, divergencia de ambiente, suite verde prod quebrada, asyncpg, aiosqlite, ORM select

**Sintoma.** Uma query escrita com `text("SELECT ...")` funciona na suíte e se comporta **diferente**
em produção — ou o contrário. Não é lógica: é **tipo**. Os dois casos medidos, no mesmo dia, no mesmo
módulo:

- **UUID.** `SELECT familia_id ...` devolve `uuid.UUID` no Postgres (que `str()` rende
  `e5215b4f-65bf-44c1-...`, com hífens) e o **hex CRU** no SQLite (`e5215b4f65bf44c1...`, sem
  hífens). Um dicionário chaveado por `str(familia_id)` sai com chaves de formatos **diferentes** em
  teste e em prod, e todo consumidor a jusante casa numa e falha na outra.
- **datetime.** Uma coluna `DateTime(timezone=True)` volta **com** fuso do Postgres e **sem** fuso do
  SQLite. Subtrair aware de naive é `TypeError`. E se o valor for lido por `text()` sem tipo
  declarado, o SQLite pode devolver a coluna como **string** — aí a subtração vira `datetime - str`.

**Causa.** O type engine do SQLAlchemy só converte quando ele sabe o tipo da coluna — o que acontece
quando você seleciona pelo **modelo** (`select(Modelo.campo)`), não quando você manda uma string SQL
opaca. Com `text()`, o resultado vem como o **driver** entregou: `asyncpg` e `aiosqlite` não
concordam, e nada avisa.

**Por que passa despercebido.** A suíte inteira concorda consigo mesma. Roda tudo em SQLite, todos
os testes veem o mesmo formato, e o par teste+código fica coerente — **coerentemente errado para
produção**. O defeito só aparece depois do deploy, num consumidor que casa chave ou faz aritmética de
data. É a pior versão do erro: descoberto tarde, longe da causa, e com a suíte servindo de álibi.

**Conserto.**

1. **Leia pelo ORM quando o valor vai ser usado como valor** (comparado, subtraído, usado como chave).
   `select(Modelo.campo)` passa pelo type engine e entrega o mesmo tipo nos dois bancos.
2. **Se o SQL cru for necessário** (agregação, `ON CONFLICT`, `DELETE` em massa), **normalize na
   saída** e diga por quê: `str(uuid.UUID(str(valor)))` rende a forma canônica venha hex ou UUID;
   um helper `comFuso()` que assume UTC quando `tzinfo is None` fecha o lado da data.
3. **Prove por mutação**, não por leitura: reverta a normalização e confirme que a suíte fica
   vermelha. Se não ficar, a normalização é especulação — e aí o problema é outro.

**Sinal de alerta na revisão.** `text(` no mesmo arquivo em que alguém monta `dict[str(algo)]` ou faz
`agora - lido_do_banco`. Não é o SQL que está errado; é a fronteira onde o tipo se perde.
