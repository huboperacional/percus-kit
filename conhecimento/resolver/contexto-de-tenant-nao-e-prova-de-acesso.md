## Contexto de tenant não é prova de acesso {#contexto-de-tenant-nao-e-prova-de-acesso}

`tags: rls, multi-tenant, postgres, autorizacao, guc, politica permissive`

**Classe:** RLS / multi-tenant / autorização
**Medido em:** PostgreSQL 17.9 e 17.10, 2026-08-24, Empresa Milionária (A10)

**Sintoma**

Tabela sob RLS isolada por `usuario_id` precisa passar a ser lida e escrita **na linha
de outra pessoa** — tela de administração de membros, transferência de titularidade,
qualquer coisa em que um administrador mexe no registro alheio.

Com a política de uma chave, medido:

```
GET  /empresas/{id}/membros   -> 1 linha onde deviam ser 2   (a tela mostra uma pessoa)
PATCH .../membros/{alvo}      -> UPDATE 0                     (404 para todo alvo real)
```

E a suíte fica **verde**, porque SQLite não tem RLS: os testes de endpoint passam
idênticos com e sem o defeito.

**A correção óbvia, e por que ela é armadilha**

O reflexo é alargar para duas chaves, espelhando alguma tabela que já faça isso:

```sql
USING (usuario_id = app.usuario_id OR empresa_id = app.empresa_id)
```

Funciona, e **abre um buraco que não aparece em teste nenhum**. `app.empresa_id`
costuma ser declarado a partir do segmento de path **antes** de a autorização
acontecer — é o padrão natural quando o tenant vem na rota (ADR-0009). No projeto
onde isto foi medido havia um caminho vivo assim: o resgate de link de capacidade
declarava a empresa do path e **só então** validava o token.

Com o `OR` simples, `app.empresa_id` sozinho passa a bastar. A proteção sai do banco e
passa a depender de **toda cláusula `WHERE` futura estar correta** — que é exatamente
o que RLS existe para não precisar. Medido, sob o contexto do link:

| Política | Linhas visíveis |
|---|---|
| `OR empresa_id` simples | **2** — a empresa inteira |
| com GUC de prova | **1** — só a própria |

**A saída: um terceiro GUC que significa "provei", não "sei"**

```sql
USING (
  usuario_id = NULLIF(current_setting('app.usuario_id', true), '')::uuid
  OR (empresa_id = NULLIF(current_setting('app.empresa_id', true), '')::uuid
      AND NULLIF(current_setting('app.papel_provado', true), '') = 'true')
)
```

`app.papel_provado` é definido **só** pela dependência que resolve o papel, e só depois
de encontrar a linha do chamador. Não é dado de domínio: é a marca de que a autorização
aconteceu nesta transação. Ela separa *"sei em que empresa estou"* de *"provei que
posso estar nela"* — e essas duas coisas não são a mesma em nenhum sistema onde o
tenant chega pela URL.

Quem esquecer de defini-la enxerga apenas a própria linha: falha **fechada e visível**
(404), nunca por excesso de leitura. É a direção certa de falha.

**Três detalhes que decidem se funciona**

1. **Derrube a política antiga pelo nome.** Políticas PERMISSIVE se somam por `OR`.
   Criar a nova sem `DROP POLICY` da antiga deixa as duas ativas, e a nova — mais
   estreita — não tem efeito nenhum. O `DROP` não é limpeza, é o mecanismo.
2. **Compare com a string exata.** `'TRUE'`, `'1'` e lixo não podem liberar. Travado
   por teste: o caso realista é alguém escrever `set_config(..., 'TRUE', true)` numa
   rota nova.
3. **`NULLIF(..., '')` nos três `current_setting`.** Contexto ausente devolve NULL e
   nega limpo; contexto definido como string vazia faz `''::uuid` estourar
   `InvalidTextRepresentationError` no meio de um `SELECT` comum. Os dois têm que
   negar igual.

**Como provar que a guarda existe**

Sabotagem obrigatória: troque o ramo pelo `OR` simples e confirme o vermelho. No caso
medido, 3 dos 6 testes caíram, cada um pelo motivo certo — e **3 continuaram verdes**,
corretamente, porque não dependem do estreitamento. Guarda que fica verde sob a
sabotagem não é guarda.

O teste que importa é o que reproduz o contexto não autorizado:
`test_contexto_de_empresa_sem_prova_nao_abre_a_lista`. Se ele ficar vermelho um dia,
alguém trocou a política pela versão de duas chaves.

⚠️ Todos estes testes precisam de PostgreSQL real. Em SQLite eles passam sem exercer
nada — ver o mesmo mecanismo do [[404-por-design-esconde-tenancy]].

**Relacionados**

- Sem `FORCE ROW LEVEL SECURITY`, o dono da tabela ignora tudo isto — e o dono é o papel da aplicação
- Ler a tabela sem aplicar o contexto devolve **zero em tudo**, e "já está limpo" vira conclusão falsa
- [[a-sabotagem-prova-o-que-voce-imaginou]]
- [[404-por-design-esconde-tenancy]]
