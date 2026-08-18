## Migration de BACKFILL (versionar row que já existe em prod) {#migration-backfill}

`tags: alembic, migration, backfill, incidente, downgrade, idempotente, ON CONFLICT`

**Quando:** algo foi inserido **direto no banco** pra destravar um incidente (`docker exec`, `psql`
na mão) e nunca virou migration. O banco de prod está certo, mas um rebuild a partir do histórico do
Alembic não teria a row — e o incidente volta.

**Passos:**
1. **Leia a row REAL de produção**, não os defaults do schema nem o que o doc do incidente diz.
   Campo que divergiu do default costuma ser exatamente o que resolveu o incidente.
2. `INSERT ... ON CONFLICT (chave) DO NOTHING` — em prod tem que ser no-op.
3. **`downgrade` = `pass`**, com docstring explicando. Isto é uma **exceção consciente e restrita à
   R6** ("sempre ter `downgrade` rastreável"): a rastreabilidade que a R6 quer está na docstring, não
   num `DELETE` que aqui seria destrutivo. Vale **só** pra backfill de row pré-existente — declare o
   motivo no próprio arquivo pra não virar precedente solto no review. (Detalhe abaixo.)
4. Valide o SQL contra o banco de prod **dentro de transação revertida**: `begin()` → roda o INSERT
   com a chave real (espera `rowcount=0`) → roda com uma chave fake (espera `rowcount=1`) →
   `rollback()`. Depois **releia** e confirme que não sobrou nada. Prova sem mutar prod.

**🔴 A armadilha principal — o `downgrade` simétrico apaga o que você não criou.** A regra normal
("sempre ter `downgrade` rastreável") assume que o `upgrade` criou a coisa. Num backfill isso é
falso: em prod o `upgrade` é no-op porque a row **já estava lá**. Um `DELETE` simétrico então remove
uma row pré-existente, e um rollback de deploy **recria o incidente original**. O Alembic não
consegue distinguir "eu criei esta row" de "ela já estava aqui" — então a escolha segura é não
deletar nunca. O custo é cosmético (num banco de dev do zero, o downgrade deixa a row pra trás); a
alternativa é um caminho automatizado capaz de derrubar o login de um produto em produção.

**Caso real (auth-service, 2026-08-14):** audience `ads4pros-site` inserida à mão em 2026-07-31 pra
matar um `422 invalid_audience`. O backfill `024` nasceu com `DELETE` no `downgrade`; o review
DeepSeek pegou. Os valores certos (`origins=[]`, `otp_require_existing_account=false`) só apareceram
lendo a row de prod — `otp_require_existing_account` no default `true` teria trocado o `422` visível
por um **drop silencioso**, que é pior de diagnosticar.
