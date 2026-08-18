## Query que MUTA e sinaliza em memória: o sinal morre na primeira leitura {#query-muta-e-sinaliza-em-memoria}

tags: `side-effect-in-getter`, `CQS`, `estado-de-sessao`, `flag-volatil`, `sinal-perdido`, `identity-map`, `python`, `sqlalchemy`, `bot`, `TTL`, `expiracao`

**Sintoma.** Uma transição de estado acontece (o banco muda, o log registra) mas **ninguém avisa o usuário**. O log prova que o código detectou a condição; a mensagem nunca sai. Reprocessar não reproduz — na segunda vez o estado já está consumido.

**Causa raiz.** Um *getter* faz três coisas: lê, **decide** a transição e **grava/commita** — e devolve o aviso num **atributo em memória** do objeto (`obj._algoAconteceu = True`). A mutação é **global e persistida**; o sinal é **local e volátil**. Basta o objeto ser descartado (outra sessão de banco, outro escopo, um `async with` que fecha) para o sinal sumir enquanto o efeito permanece.

**O que torna isso quase certo em produção:** o caminho de entrada raramente lê o estado **uma** vez. Meça antes de supor — num caso real eram **3 leituras por mensagem** no caminho imediato e 3 no debounced. A primeira consumia; a que avisaria era a terceira. O contrato era inviável **por construção**, não "quebrado por um call-site".

**Diagnóstico em 2 passos:**
1. Ache o log da transição e confirme que ele SAI (`docker logs ... | grep <evento>`). Se sai e o usuário não recebe nada, o sinal está se perdendo entre a detecção e o emissor.
2. Conte os call-sites do getter **por AST**, e mapeie cada um à função que o contém. Se dois rodam na mesma requisição, o bug já existe.

**Solução — separar em três, não em duas:**
- **leitura pura**: não grava, não commita; devolve `(objeto, status)` com o status **derivado** dos campos. Derivado é o que faz N leituras concordarem.
- **transição com dono único**: uma função que grava, chamada de um ponto explícito do ciclo, que também emite o aviso. Efeito e sinal viram a **mesma sentença**.
- **tipo de retorno que obriga a tratar**: tupla (ou objeto) em vez de atributo opcional. Atributo opcional é o que permitiu 12 de 13 call-sites simplesmente não lerem o sinal.

⚠️ **A ordem importa e a inversa cria um bug PIOR.** Se a limpeza que o getter fazia também protegia consumidores downstream (ex.: apagar o contexto impedia um handler de agir sobre pendência velha), tornar a leitura pura **antes** de a transição ter dono troca "aviso perdido" por "agiu no alvo errado". Dê o dono primeiro; e adicione um acessor (`contextoVigente(obj, status)`) que devolve vazio quando o status é inválido, para que um ponto de entrada novo que esqueça o dono degrade para "não avisou" em vez de "escreveu errado".

**Ref:** Família Milionária, 2026-08-17. `getSession` mutava+commitava e marcava `_wasExpired` só na instância; o peek do gate de debounce (sessão de banco própria, descartada) consumia a expiração e o dispatcher via "ativa". Uma resposta "sim" 64h depois virou lançamento novo alucinado e a despesa real ficou fora do ledger. Ver `#trava-vermelha-no-dia-1` e `#parametro-adicionado-sem-propagar`.
