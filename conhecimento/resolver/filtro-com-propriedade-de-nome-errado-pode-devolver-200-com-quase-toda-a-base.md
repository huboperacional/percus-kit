## Filtro de busca com o nome de propriedade ERRADO pode devolver 200 com quase toda a base, não 400 {#filtro-com-propriedade-de-nome-errado-pode-devolver-200-com-quase-toda-a-base}

tags: hubspot, crm search api, lastmodifieddate, hs_lastmodifieddate, fallback defensivo, falha silenciosa, propriedade inexistente, contacts, deals, medicao vs suposicao

**Sintoma:** um job de sincronização incremental precisava filtrar por "data de modificação" de
um objeto (Contact) do HubSpot, mas o nome exato da propriedade nunca tinha sido medido contra o
portal real — só uma suposição informada (Contact é o objeto mais antigo do HubSpot e
tradicionalmente usa `lastmodifieddate` sem prefixo, ao contrário de Deal/Ticket que usam
`hs_lastmodifieddate`). O plano desenhou uma defesa: se a suposição estivesse errada, o filtro
"deveria" devolver 400 (nome de propriedade inválido), e o código trataria isso como sinal pra
trocar de propriedade.

**Causa raiz:** essa defesa parte de uma suposição sobre o comportamento de erro da API que
NUNCA foi medida. Medido contra o D4U real (janela de 5 anos): filtrar por `lastmodifieddate`
(a propriedade correta) devolveu **207** contatos; filtrar pela ERRADA, `hs_lastmodifieddate`
(que não existe no objeto Contact), devolveu **200 OK** com **246.339** contatos — 1.190× mais,
não um erro. A propriedade desconhecida parece ser tratada pela Search API como sempre-ausente, e
a comparação `GTE/LTE` contra um valor ausente aparentemente casa (ou o filtro inteiro é
ignorado), devolvendo perto da base inteira do tenant em vez de zero ou erro. Ou seja: **a
propriedade errada não falha ruidosamente — falha silenciosamente, devolvendo uma população
gigante sem relação nenhuma com "o que foi modificado depois do cursor".** Um job de
sincronização que apostasse na propriedade errada teria "funcionado" sem 400, sem exceção, com
`sync_log.status='ok'` — só que reprocessando a base inteira a cada tick, pra sempre, sem
convergir num incremental de verdade, e sem nenhum alarme apontando a causa.

**Por que isso generaliza:** qualquer defesa desenhada como "SE a suposição estiver errada, ISSO
vai estourar erro e a gente troca" é uma aposta dupla — não só a suposição principal, mas TAMBÉM
a suposição de que o desvio produz um sinal de erro detectável. As duas precisam ser verdadeiras
pra defesa funcionar, e a segunda é frequentemente mais frágil que a primeira (portais REST tendem
a ser tolerantes com nomes de campo desconhecidos em filtros, não estritos). Ver também
`wrong_literal_defeats_fallback_empty_would_use` e `filter_does_filter_returns_200` na memória
do projeto — mesma família: "o filtro não filtrou, e o 200 parece sucesso".

**Solução:** quando o custo de errar é alto (aqui: 100% dos incrementos de um tenant de produção
correndo contra a população errada, sem alarme), **não confie em "vai estourar erro" como a única
rede de segurança** — meça a propriedade real ANTES de decidir qual é a fonte de verdade, mesmo
que isso signifique uma chamada extra de baixo custo (aqui: duas buscas com `limit=1`, uma por
candidato) num script de calibração dedicado, rodado uma vez contra produção antes do deploy do
mecanismo que depende da escolha. Se a medição não for possível antes do primeiro deploy, pelo
menos desenhe uma segunda verificação que INDEPENDA do comportamento de erro da API — por exemplo,
comparar a contagem devolvida por cada candidato contra uma faixa plausível conhecida por outra
fonte (aqui: ~150 contatos/dia × dias da janela), e tratar um desvio de ordem de magnitude como
sinal de propriedade errada, não confiar em "não deu 400 = está certo".
