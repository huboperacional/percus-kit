## "Senha errada" que é o seu parser levando as aspas do `.env` junto {#env-parse-aspas-senha-falsa}

tags: password authentication failed, senha errada, .env, dotenv, parser, aspas, quotes, strip, psql, PGPASSWORD, DATABASE_URL, falso negativo, credencial valida

**Contexto:** você lê o `.env` com um `split` caseiro, monta a conexão e o Postgres responde
`FATAL: password authentication failed for user "..."`. A credencial parece errada, e você começa a
investigar role, `pg_hba` e provisionamento — tudo caminho errado.

**Causa raiz:** o valor no `.env` está entre aspas, e `split("=", 1)[1]` devolve o valor **com as
aspas**. O cliente manda as aspas como parte da senha. Bibliotecas de dotenv tiram; o seu `split`
não.

**Solução:** aplique `strip()` e remova aspas simples e duplas das pontas — ou use
`python-dotenv`/`dotenv_values` em vez de parsear à mão.

**Como não perder tempo de novo:** antes de suspeitar da credencial, imprima o **comprimento** do
valor lido (nunca o valor). Dois caracteres a mais que o esperado são as aspas.

**Ref:** Empresa Milionária, Fase 0, 2026-08-11. Custou ~20 minutos e uma tentativa desnecessária de
`ALTER ROLE`; a credencial estava correta desde o começo.
