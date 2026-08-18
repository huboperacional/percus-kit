## Bug de LLM "não reproduz mais": o GATILHO envelhece, o MECANISMO não — cace a frase vizinha medindo o extrator offline {#gatilho-llm-envelhece-mecanismo-fica}

`tags: llm, nao reproduz mais, gatilho, frase exata, extrator, smoke prod, 5t, guarda, modelo muda, drift do modelo, reproduzir bug nao deterministico, medir offline, generateDesiredCart, taxa nao e constante`

**Sintoma:** você precisa de um smoke vivo pro caminho de defeito de uma guarda, mas a frase que
reproduziu o bug "2/2" dias atrás agora sai **certa toda vez**. Fica a tentação de (a) declarar
`[5-T]` porque "o resultado está certo" ou (b) gastar dezenas de smokes reais na esperança de
azarar.

**Contexto (tiatendo, C18, 2026-08-11):** guarda de ancoragem deployada em `0.297.0`; faltava um
evento vivo de `mismatch`. A frase original (`Torre e meia R$ 95,00 de feijoada` depois de uma linha
de strogonoff) tinha reproduzido 2/2 em 10/08 e 0/5 em 11/08.

**Causa raiz:** o modelo por trás do extrator muda sem aviso. Medido chamando
`generateDesiredCart` direto no container: **22/22 gerações corretas**, inclusive replayando o
estado REAL do turno defeituoso (draft aberto, janela montada por `historyForGenerator`) e outro
turno defeituoso de um mês antes. As **3** frases historicamente quebradas do corpus estavam
curadas. O mecanismo do defeito, porém, continuava vivo — só tinha mudado de par de pratos: a frase
vizinha, com dois pratos que compartilham um token (`strogonoff **de frango**` +
`bobó **de frango**`), reproduziu `mismatch` **3/4** offline e **2/3** ao vivo, e fechou o `[5-T]`.

**Solução (a ordem importa, e é barata):**
1. **Meça o componente não-determinístico offline, com o código de PRODUÇÃO**, dentro do container:
   ~3s por geração, nenhuma conversa real tocada. Monte as entradas pelos mesmos helpers que
   produção usa (aqui: `historyForGenerator`) — replay que reimplementa a política mede um mundo que
   não existe.
2. **Replay o estado REAL** do turno que falhou (draft, janela, carrinho anterior), não só o texto.
   Se ele acertar N/N, o gatilho morreu — pare de repetir a frase.
3. **Varra frases VIZINHAS em lote** (8 candidatos × 4 gerações ≈ 2 min), derivadas do mecanismo
   hipotetizado, não do texto original. Aqui o mecanismo era "prato da 2ª linha herdado da 1ª quando
   a linha começa pela variante"; a vizinha que quebrou aumentou a colisão de nome entre os pratos.
4. **Só então gaste o smoke real**, com a frase de maior taxa medida — e **limpe o estado entre
   tentativas**: o carrinho que o smoke anterior deixou vira `previousDishes` e faz a guarda dizer
   `ancorado` legitimamente (RF6), mascarando o defeito.

**Consequência que vale além do caso:** toda taxa medida sobre saída de LLM é **foto, não
constante**. Já se sabia que o denominador podia ser frágil (corpus sem cliente real); esta sessão
mostrou o **numerador** se movendo sozinho. Critério de aceite que fixa um limiar sobre taxa de
defeito de LLM precisa datar a medição e prever re-medição — e reproduzir um bug de LLM meses depois
é **re-procurar o gatilho**, nunca repetir a frase.

**Relacionado:** [#smoke-certo-mas-caminho-nao-rodou] (confirme o caminho pelo evento/log, nunca
pela saída) · [#smoke-prod-feature-llm] (frase exata do caso original) ·
[#mock-sig-llm-hipotese-errada-precisa-smoke-real] (mock não substitui LLM vivo).

**Ref:** tiatendo, frente C18, PROD `0.297.0` (2026-08-11). Eventos
`cart_anchor='mismatch_perguntou'` em `20:59:04` e `20:59:57` UTC. R23.

### Adendo 2026-08-12 — os dois eixos de perturbação que mais renderam, e o achado estrutural

A frase original do C18 envelheceu de novo (**5/5 correta** em 12/08). O passo 3 acima ("varra
frases vizinhas derivadas do MECANISMO") funcionou, e vale registrar **quais eixos** pagaram —
eles são baratos e reutilizáveis em qualquer extrator multi-linha:

1. **Inverta a ORDEM das linhas.** Mesmo conteúdo, ordem trocada: `Torre e meia … feijoada` na
   linha 1 e `G … strogonoff` na linha 2 quebrou **5/5**, enquanto a ordem original acertava 5/5.
2. **Varie o PARENTESCO entre os rótulos**, não o prato. Medido 3/3 em cada combinação:
   `Torre e meia`→`G` **ERRA**; `M`→`G`, `G`→`M` e `Torre`→`Torre e meia` acertam. O defeito exige
   que o rótulo da linha ANTERIOR **contenha o da seguinte como prefixo** (`Torre e meia` ⊃
   `Torre`) — e é direcional. Caracterizar isso custou 12 gerações e transformou "o extrator às
   vezes erra" num gatilho determinístico com teste possível.

**O achado que só apareceu ao perguntar "quem pega isso?":** o projeto tinha **6 guardas** dessa
família, e **nenhuma pegava** — porque todas conferem o **PRATO** contra o texto e nenhuma confere
a **VARIANTE**. Os dois pratos estavam certos, então a ancoragem dizia `ancorado`, o `decideDiff`
dava lastro às duas adições, e o turno **aplicava R$ 175,00 no lugar de R$ 125,00**. Lição
transferível: ao fechar uma família de guardas, pergunte **qual CAMPO cada uma valida** — seis
defesas em volta do mesmo campo deixam o vizinho descoberto, e o vizinho é onde o dinheiro vaza.

**Como verificar o "quem pega isso?" sem deploy:** alimente as funções puras de decisão com a
saída medida do LLM e o cardápio real (`computeDiff` → `decideDiff` → guardas), e leia os baldes.
É determinístico, roda em segundos e responde "aplica / pergunta / descarta" antes de qualquer
smoke. Ref: tiatendo, frente E1 (2026-08-12).
