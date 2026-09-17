## A chave de acesso da NFS-e nacional traz o documento do EMITENTE, não o do prestador: decidir o lado da nota por ela exige freio {#chave-de-acesso-da-nfse-nacional-traz-o-emitente-nao-o-prestador}

`tags: nfse, nota fiscal de serviço, chave de acesso, emitente, prestador, tomador, intermediário, tpEmit, danfse, pdf, a pagar, a receber, sefin nacional, leiaute`

**Sintoma:** um leitor de PDF de NFS-e acha a chave de acesso de 50 dígitos, confere o DV e usa o CPF/CNPJ embutido nela
(posições 10 a 23, com o tipo de inscrição na 9) para decidir se a nota é **a receber** (a empresa emitiu) ou **a pagar**
(outro emitiu e a empresa aparece no documento). A regra passa em todos os testes com notas sintéticas. Medido em
2026-09-16/17 no leiaute oficial (Empresa Milionária, leitura de NFS-e, Tasks 1 e 8).

**Causa raiz:** pelo XSD nacional v1.01 e pelo Anexo I, a chave carrega o documento do **emitente** da DPS, e `tpEmit`
diz quem emitiu: 1 prestador, 2 tomador, 3 intermediário (regras E1282/E1285). O prestador mora em `infDPS/prest`, não
em `emit`. O PDF (DANFSe) **não** imprime `tpEmit`. "Emitente = prestador" só vale porque a Sefin Nacional hoje recusa
`tpEmit` 2 e 3 (E9996). Isso é regra de operação atual, não do leiaute, e pode mudar.

**Solução:**

1. No XML, leia o prestador de `infDPS/prest` e use `emit` para o nome só quando `tpEmit` = 1.
2. No PDF, trate a decisão pela chave como suposição declarada, com freio para o lado de "a completar": a pagar só
   quando não há documento além da empresa e do emitente; a receber com no máximo um outro documento. Na dúvida, não
   decida o tipo.
3. Declare o que o freio não pega: nota emitida pelo **tomador** contra a empresa prestadora, com só as duas partes
   impressas, é lida a pagar (tipo trocado). Reavalie quando a Sefin aceitar `tpEmit` 2 e com DANFSe real.
4. Nunca decida o tipo por rótulo impresso ("Prestador", "Tomador") no texto do PDF.
