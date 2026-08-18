## Auditoria de conta de anuncios: validar a PROPRIA proposta nao acha erro de ausencia {#auditoria-validar-propria-proposta-nao-acha-ausencia}

`tags: auditoria, conta de anuncios, google ads, erro de ausencia, reestruturacao, checagem para dentro, palavra orfa, negativa presa, baseline externo, o que ficou de fora`

**Sintoma:** a reestruturacao passa em todas as checagens (limite de caractere, URL viva, status
relido da API) e mesmo assim a melhor palavra da conta fica sem dono. Medido em 2026-08-11 na
Imobiliaria UNI: `imoveis dourados ms` — 387 cliques, R$ 733,63 e 4 conversoes em 30 dias — fora da
estrutura nova, junto com 603 cliques e METADE das conversoes da conta. O plano previa pausar o
grupo antigo, o que teria tirado do ar exatamente o que mais funcionava.

**Causa:** toda checagem olhava PARA DENTRO da proposta. Erro de ausencia nao se detecta olhando o
que esta presente. No mesmo dia a mesma causa produziu mais quatro: negativas presas no grupo antigo
(grupos novos nascem desprotegidos), campanha Smart com 34% do orcamento fora do escopo (auditei o
que me apontaram, nao onde o dinheiro estava), `hectares` julgado como medida de area quando e o
bairro de maior padrao da cidade, e uma linha ausente na tabela lida como "esse cliente nao existe".

**Solucao:** gate que compara o HISTORICO COM RESULTADO contra a estrutura ATIVA, com exit code.
`docs/auditorias/gate_cobertura.py` no Paid Media. Dois usos, mesmo motor:
- cobertura de migracao: `--campanha <id>` (nao suba abaixo de 95% das conversoes)
- perda antes de pausar: `--campanha <id> --pausar "<grupo>"`
Casamento frouxo de proposito (normaliza acento/caixa, substring nos dois sentidos): falso
"descoberto" vira ruido e ninguem le o relatorio depois. Se acusa buraco, o buraco e real.
**Prove o gate nos DOIS sentidos** — reconstruindo o estado do erro ele tem que REPROVAR.

**Armadilha ao medir o proprio gate:** `python gate.py | tail -20; echo $?` devolve o codigo do
`tail`, nao do python. Medi `exit=0` num REPROVADO e quase commitei um gate que so imprime.

**Cliente com CMS Praedium (imobiliaria) publica feed VRSync** com bairro/tipo/preco de cada imovel:
e a verdade de estoque E o dicionario que classifica termo de bairro que a auditoria nao sabe
julgar. `docs/auditorias/inventario_vrsync.py`. Sem User-Agent o bucket devolve 403. `AccessDenied`
do S3 e ambiguo (chave inexistente e chave privada dao o mesmo erro quando falta `ListBucket`) —
em 2026-08-11 era arquivo que nunca tinha sido gerado. **Feed de um cliente NUNCA entra na decisao
de outro: planejamento e tenant a tenant.**

**Ao mutar Google Ads:** `FieldMask` vem de `google.protobuf.field_mask_pb2`, NAO de
`client.get_type("FieldMask")` (levanta `ValueError` e deixa a acao CRIADA e NAO promovida — a
armadilha da acao de upload que recebe dado e nao conta). Script que cria e depois promove precisa
ser idempotente, e o log tem que distinguir "encontrei o que EU criei numa execucao anterior" de
"ja existia na conta do cliente".

Skill que impoe a ordem: `.claude/skills/auditoria-de-conta/SKILL.md` (Paid Media).
