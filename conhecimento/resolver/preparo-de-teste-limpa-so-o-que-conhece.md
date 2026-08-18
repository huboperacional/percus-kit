## Dois módulos de teste passam sozinhos e quebram juntos: cada preparo limpa só o que ELE conhece {#preparo-de-teste-limpa-so-o-que-conhece}

tags: teste de integracao, fixture, banco compartilhado, drop_all, create_all, alembic_version, ordem alfabetica, interferencia entre modulos, DependentObjectsStillExistError, DROP SCHEMA CASCADE, estado externo, teste flaky por ordem

**Contexto:** dois módulos de teste batem no mesmo banco real e montam o schema de formas
diferentes — um por `create_all` de um recorte de tabelas, outro por `alembic upgrade head`.
Cada um passa sozinho. Juntos, um deles fica todo vermelho, e trocar a ordem muda quem quebra.

**O que está acontecendo:** o preparo de cada módulo foi escrito olhando só para o que **aquele
módulo** cria. Isso é invisível enquanto ele é o único no banco, e vira defeito no dia em que
outro chega. Os dois sintomas são complementares e parecem problemas diferentes:

- **Limpar por lista de tabelas** falha quando existe uma tabela FORA da lista apontando para
  dentro dela: `DependentObjectsStillExistError: cannot drop table X because other objects
  depend on it`. A lista está certa sobre o módulo dela e errada sobre o banco.
- **Decidir a limpeza por um marcador** — "se `alembic_version` existe, faço `downgrade`" —
  falha quando o outro módulo monta o schema por `create_all`, que não grava marcador nenhum.
  A fixture conclui "banco limpo", pula a limpeza, e o `upgrade` estoura em tabela existente.

A causa é a mesma nos dois: **preparo baseado em conhecimento parcial do que existe no banco**.

**A correção que NÃO resolve:** zerar o banco antes de rodar a suíte. Isso conserta a rodada,
não a suíte — que continua correta só enquanto ninguém rodar um módulo isolado, interromper uma
rodada no meio, ou renomear um arquivo para antes do outro na ordem alfabética. Estado externo
como pré-condição não declarada é a mesma classe de defeito, só que mais difícil de ver.

**Solução:** o preparo não pergunta nada ao banco — derruba o schema inteiro e recria.

```python
async def zerarSchema(url: str) -> None:
    exigirBancoDeTeste(url)          # ver a guarda abaixo
    motor = create_async_engine(url, poolclass=NullPool)
    try:
        async with motor.begin() as conexao:
            await conexao.execute(text("DROP SCHEMA IF EXISTS public CASCADE"))
            await conexao.execute(text("CREATE SCHEMA public"))
    finally:
        await motor.dispose()
```

`CASCADE` é o ponto: ele derruba a tabela **e o que depende dela** na mesma operação, que é
exatamente o que uma lista escrita à mão não faz quando está incompleta. Cada módulo chama isso
no próprio setup, e aí ordem de coleta e estado anterior deixam de existir como variáveis.

**A guarda que tem que vir junto.** A limpeza passou a ser destrutiva de verdade: antes, apontar
a URL de teste para o banco errado custava as tabelas do recorte; agora custaria o banco inteiro
do produto vizinho no mesmo servidor. Exija que o nome do banco termine em `_test` e levante
quando não terminar — com teste que prova a recusa citando o banco de produção pelo nome. **Não
deixe essa guarda para depois:** ela é o que mantém o preço do engano do mesmo tamanho que ele
já tinha.

**Como provar que fechou** — rodar duas vezes não basta, porque a segunda herda o estado
saudável que a primeira deixou. Rode partindo de cada estado hostil:

1. banco no estado que quebrava (migrado, no caso de origem);
2. imediatamente de novo, sem tocar em nada;
3. **ordem invertida** dos módulos, explicitamente na linha de comando;
4. banco montado pelo OUTRO mecanismo (`create_all` sem marcador de versão);
5. a suíte inteira do marcador, para o número oficial.

**Sobre o cronômetro:** se a suíte roda contra banco em VPS por túnel SSH, meça o round-trip
antes de acusar a suíte de travada. Medido no caso de origem: ~470 ms por round-trip, 4,6–7,1 s
para abrir conexão, 27 s num `create_all` de 9 tabelas — nove minutos de rodada que são quase
todos latência de rede, e que estouram o timeout de qualquer comando em foreground. Rode em
background e não confunda lento com travado.

**Ref:** Empresa Milionária, Fase A, 2026-08-13 — `test_isolamento_fk_postgres.py` (recorte por
`create_all`, prova que o dialeto aceita o DDL) e `test_migration_postgres.py` (schema por
`alembic upgrade head`, prova que o banco nasce da migration). 8 erros juntos, 0 separados.
Entradas vizinhas: `#alembic-autogenerate-nao-ve-check-rls-revoke`,
`#rls-sem-force-dono-ignora-politica`.
