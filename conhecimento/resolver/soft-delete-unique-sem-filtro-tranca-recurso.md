## Soft-delete + UNIQUE sem filtro = recurso trancado pra sempre {#soft-delete-unique-sem-filtro-tranca-recurso}

`tags: soft-delete, is_active, UNIQUE, constraint sem filtro, indice parcial, 409 ja existe, beco sem saida, listagem filtrada`

**Sintoma:** o usuário tenta cadastrar algo, leva `409 já existe`, e **não vê nada na tela** que
possa apagar ou editar. Beco sem saída pela UI.

**Causa:** `DELETE` é soft (`is_active = false`), a listagem filtra `is_active = true`, mas a
constraint é `UNIQUE (dono, chave)` **sem filtro de ativos**. A linha que bloqueia existe pro
banco e não existe pro usuário.

**Conserto certo — RESSUSCITAR, não criar outra:** no `POST`, se achar a linha e ela estiver
inativa, faça `UPDATE ... SET is_active = true` **preservando o id**. Criar linha nova (ou tornar
o índice parcial com `WHERE is_active`) parece equivalente e não é: o id costuma estar embutido
em algo externo já distribuído — aqui, o marcador `pma-tracker-init:<id>` no HTML do site do
cliente. Id novo ⇒ a página passa a reprovar na validação sem ninguém ter mexido nela.

Zere também o estado derivado (status de validação, timestamps) — o que a linha sabia envelheceu
enquanto ela esteve fora da varredura.

**Como procurar no seu projeto:** `grep` por `is_active`/`deletedAt` e cruze com as constraints
`UNIQUE` da mesma tabela. Toda combinação sem filtro parcial é um beco esperando acontecer.

**Ref:** paid-media, commit `64127a7a`. Travou o operador em produção. R23.
