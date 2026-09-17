## Sabotagem de ORDEM de recusas cai no CHECK do banco antes da asserção quando a entrada viola a coluna que a outra recusa grava {#sabotagem-de-ordem-cai-no-check-do-banco-antes-da-assercao}

`tags: sabotagem, ordem de recusas, check constraint, IntegrityError, flush, registro de uso, teste, pytest, caso de uso, validação`

**Sintoma:** para provar que a recusa A vem antes da recusa B, sabota-se a ordem (B passa a vir antes) e espera-se o teste
vermelho na asserção do motivo. O teste fica vermelho, e parece prova. Só que o vermelho é `IntegrityError` no `flush`,
antes da asserção: a recusa B grava um registro de uso, e a entrada do teste viola um CHECK da coluna que B grava. Medido
em 2026-09-17 (Empresa Milionária, leitura de NFS-e, Task 10): o teste "nome inválido vence arquivo vazio" usava nome em
branco, e o registro de `arquivo_vazio` gravaria nome `""`, violando `ck_leitura_documento_nome_preenchido`.

**Causa raiz:** a entrada escolhida viola as DUAS coisas: a regra de cima (nome inválido) e a restrição do banco que só a
gravação de baixo alcança. Com a ordem certa, a recusa de cima grava sem nome e nunca chega ao CHECK. Com a ordem trocada,
quem estoura é o banco, não a regra.

**Solução:**

1. Para cada par da ordem, pergunte: "se a ordem inverter, a gravação da outra recusa passa no banco?". Se não passar,
   troque a entrada por uma que viole só a regra de cima (aqui: nome de 256 caracteres, inválido para a regra e aceito
   pela coluna).
2. No relatório da sabotagem, `IntegrityError`, `StopIteration` e `KeyError` contam como vermelho **antes** da asserção:
   declare, não conte como prova.
3. Vizinhos: `teste-que-acha-item-por-next-fica-vermelho-antes-da-assercao` e a memória "sabotagem prova UMA asserção".
