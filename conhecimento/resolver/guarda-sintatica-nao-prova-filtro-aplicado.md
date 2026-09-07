## Guarda sintática não prova filtro aplicado {#guarda-sintatica-nao-prova-filtro-aplicado}

tags: teste, guarda, ast, autorizacao, medicao

Guarda por `ast` ("este módulo chama o helper de escopo?") funciona para propriedade **sintática** e
falha para propriedade **semântica**. Antes de escrever uma, pergunte de qual das duas se trata.

- **Sintática, funciona:** `response_model=` está no decorator ou não está. A URL do endpoint é um
  literal achável em `ast.Constant`.
- **Semântica, NÃO funciona:** "o `stmt` foi de fato filtrado". Isso é fluxo de dados por variáveis
  locais, closures e funções auxiliares — indecidível por padrão sintático sem reimplementar análise
  de fluxo.

Contraexemplo medido no próprio repo (Plexco Tasks, 2026-09-07): `dashboard.py:415` **chama**
`get_visible_project_ids` e passaria em qualquer guarda do tipo "o helper é referenciado aqui". Mas
só duas das nove consultas recebem `allowed_project_ids`; as sete de tarefa não recebem nada. Uma
guarda `ast` estaria **verde sobre um vazamento real**.

**O que usar no lugar:** teste **comportamental de paridade** — exercite as superfícies de verdade,
com a mesma pessoa e o mesmo recurso, e reprove se duas discordarem. Ele não pode ser enganado por
um retorno descartado, porque mede o efeito e não a chamada.

Duas exigências para o teste de paridade não virar vácuo:

1. **Controle positivo.** Prove que o cenário tem o que vazar (que o predicado de fato restringe a
   pessoa seedada). Sem isso, um zero nos testes de vazamento passa vacuamente.
2. **Superfícies ainda não cobertas ficam `xfail(strict=True)`** — vermelhas *declaradas*, nunca
   ausentes. `strict=True` faz o teste falhar por "passou inesperadamente" quando alguém corrigir a
   superfície, o que obriga a atualizar o livro-razão no mesmo commit.

A guarda `ast` ainda serve como **tripwire secundário** ("nasceu um endpoint sem menção nenhuma ao
helper"), desde que a limitação esteja escrita na própria docstring. Ver
[teste-que-passa-sem-exercitar-o-caminho](#teste-que-passa-sem-exercitar-o-caminho).
