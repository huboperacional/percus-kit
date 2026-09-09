## Filtro de busca com o nome de propriedade ERRADO devolve 200 com quase NADA, não 400 nem a base inteira {#filtro-com-propriedade-errada-devolve-200-com-quase-nada}

tags: hubspot, crm search api, lastmodifieddate, hs_lastmodifieddate, fallback defensivo, falha silenciosa, propriedade quase vazia, contacts, deals, medicao vs suposicao, sub-coleta silenciosa

> ⚠️ **Este verbete foi CORRIGIDO em 2026-09-04.** A primeira versão (arquivo
> `filtro-com-propriedade-de-nome-errado-pode-devolver-200-com-quase-toda-a-base.md`, agora
> removido) registrou os dois números **trocados** e por isso ensinava a lição ao contrário.
> A medição que a desmentiu está no fim, e foi feita com as duas propriedades **na mesma
> execução, mesma janela, mesmo cliente** — o desenho que a versão original não teve.

**Sintoma:** um job de sincronização incremental precisa filtrar por "data de modificação" de um
objeto (Contact) do HubSpot, mas o nome exato da propriedade nunca foi medido contra o portal
real — só uma suposição informada (Contact é o objeto mais antigo do HubSpot e tradicionalmente
usa `lastmodifieddate` sem prefixo, ao contrário de Deal/Ticket, que usam `hs_lastmodifieddate`).
O plano desenhou uma defesa: se a suposição estivesse errada, o filtro "deveria" devolver 400
(nome de propriedade inválido), e o código trataria isso como sinal pra trocar de propriedade.

**Causa raiz:** essa defesa parte de uma suposição sobre o comportamento de ERRO da API que nunca
foi medida. Medido contra o D4U real, janela de 5 anos, as duas na mesma execução:

| propriedade no filtro | HTTP | `total` devolvido |
|---|---|---|
| `lastmodifieddate` (a **correta** pra Contact) | 200 | **246.487** |
| `hs_lastmodifieddate` (a **errada** pra Contact) | 200 | **207** |

Ou seja: a propriedade errada **não** dá 400, e **não** devolve a base inteira — ela devolve
**quase nada**. `hs_lastmodifieddate` existe no schema de Contact, mas está preenchida em só 207
dos 246.487 contatos, então o `GTE/LTE` casa com esses 207 e mais ninguém. O resultado é um 200
OK, sem exceção, com uma população 1.190× MENOR que a real.

**Por que isso é pior do que um erro barulhento:** um job que apostasse na propriedade errada
teria rodado com `sync_log.status='ok'`, sincronizado **207 de 246.487 contatos (0,08% da base)**,
gravado o cursor como se tivesse visto tudo, e convergido num incremental "estável" que nunca mais
traria ninguém. Toda tela que lesse esse snapshot mostraria números plausíveis-porém-minúsculos,
e nada — nem log, nem alarme, nem status — apontaria a causa. **Sub-coleta silenciosa é mais
difícil de detectar que sobre-coleta:** uma base que reprocessa demais estoura teto, custo ou
tempo e aparece; uma base que coleta 0,08% só parece um cliente pequeno.

**Por que isso generaliza:** qualquer defesa desenhada como "SE a suposição estiver errada, ISSO
vai estourar erro e a gente troca" é uma aposta dupla — não só a suposição principal, mas TAMBÉM
a suposição de que o desvio produz um sinal de erro detectável. As duas precisam ser verdadeiras
pra defesa funcionar, e a segunda costuma ser mais frágil: portais REST tendem a ser tolerantes
com nome de campo desconhecido (ou, como aqui, o nome até EXISTE — só está vazio), não estritos.
Ver também `wrong_literal_defeats_fallback_empty_would_use` e `filter_does_filter_returns_200` na
memória do projeto — mesma família: "o filtro não filtrou o que você acha, e o 200 parece
sucesso".

**Solução:** quando o custo de errar é alto (aqui: 100% dos incrementos de um tenant de produção
correndo contra a população errada, sem alarme), **não confie em "vai estourar erro" como rede de
segurança** — meça a propriedade real ANTES de decidir qual é a fonte de verdade. O custo é
ridículo: duas buscas com `limit=1`, uma por candidato, **na mesma execução e na mesma janela**,
comparando o `total`. E compare o vencedor contra uma faixa plausível conhecida por outra fonte
(aqui: ~150 contatos/dia × dias da janela) — um desvio de ordem de magnitude **pra menos** é tão
suspeito quanto pra mais.

**Lição de método, além da API:** a primeira versão deste verbete inverteu os dois números porque
as duas medições foram feitas **separadas**, e o resultado foi transcrito de memória pra prosa. Ao
registrar uma comparação A-vs-B que vai virar conhecimento, **rode as duas pontas na mesma
execução e cole a saída crua** — a tabela acima veio de um `print` único, não de duas anotações
reconciliadas depois. Comparação separada no tempo é comparação que aceita troca de rótulo sem
protestar.

**Ref:** Paid Media Automation, item 11 (Leads local do HubSpot), Task 9 (2026-09-04, medição
original invertida) e a re-medição de desempate na sessão de Task 10 do mesmo dia, feita porque
`docs/STATUS.md` e o comentário de `contacts_sync.py:64-66` afirmavam coisas opostas sobre os
mesmos dois números. O **código sempre esteve certo** (`_PROPRIEDADE_LASTMOD = "lastmodifieddate"`);
o que estava invertido era a narrativa em volta dele.
