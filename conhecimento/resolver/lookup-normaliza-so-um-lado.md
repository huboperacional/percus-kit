## Lookup por identificador "normalizado" só de um lado {#lookup-normaliza-so-um-lado}

`tags: match exato, telefone, E.164, DDI, formato armazenado, normalizacao, unknown_phone, drop silencioso, regexp_replace, canonicalizacao, dado legado`

**Contexto:** a borda canonicaliza o identificador que **chega** (telefone, CPF, e-mail, código)
e faz `WHERE coluna = :valor_canonico`. Funciona pra maioria e falha pra uma minoria sem
padrão — que some **sem erro**: nada logado como falha, nenhuma resposta ao usuário, só um
contador genérico de "não encontrado".

**Causa raiz:** a coluna **armazenada** nunca foi canonicalizada. Cadastro antigo, importação,
tela sem máscara e API externa depositaram convenções diferentes na mesma coluna (com `+`, sem
código do país, com pontuação). Canonicalizar só a entrada resolve metade do problema e esconde
a outra: a comparação é entre uma forma limpa e um campo sujo.

**Solução:** normalize **os dois lados** na comparação (ex.: `regexp_replace(col,'\D','','g')`)
e trate a canonicalização da coluna como **higiene**, não pré-requisito — assim o conserto não
fica bloqueado numa migração de dado. Se precisar de uma forma "curta" (sem prefixo/DDI) como
candidato, **guarde por validação de país/tipo**: remover `55` cegamente transforma o lookup num
coringa global (`679…` é Fiji, não DDD 67).

⚠️ **Ordem importa.** Tolerar formato faz linhas que hoje não casam passarem a casar: quem tinha
1 match passa a ter N. **Tenha a regra de desempate ANTES** — senão você troca um bug silencioso
(drop) por um intermitente (escolha que oscila), que é pior. Ver
[coluna de ordenação nunca escrita](coluna-ordenacao-nunca-escrita.md).

**Ref:** Plexco Tasks, ADR-0013 (2026-07-23). 6 de 12 linhas de `users.phone` estavam fora do
canônico; o telefone do próprio operador nunca resolvia.
