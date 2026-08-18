## Hook fica lento e trava os commits: diretorio de estado que so cresce {#estado-append-only-trava-hook}

`tags: hook lento, pre-commit trava, pendura, timeout, commit lento, diretorio cresce, append only, marcador por timestamp, TTL, stat em N arquivos, ls -t, git bash windows, O(N), latest fixo, escrita atomica`

**Sintoma:** de repente o commit demora dezenas de segundos ou pendura, e nada no diff mudou de tamanho. Pode travar **todos** os commitS do projeto.

**Causa raiz:** um hook le o "mais recente" de um diretorio de estado fazendo `stat` em **todos** os arquivos (laco `-nt` ou `ls -t`/`Sort-Object LastWriteTime`). O produtor grava **um arquivo novo por evento** (ex.: `<timestamp>.jsonl`). O diretorio cresce sem limite; no git-bash do Windows cada `stat` e caro, e o custo do hook vira O(N) sobre milhares de arquivos. Os marcadores tinham TTL de minutos e zero valor depois -- puro acumulo.

**Solução:**
1. **O produtor grava sempre no MESMO path fixo** (`latest.jsonl`), sobrescrevendo. O leitor faz `stat` em **um** arquivo conhecido -- O(1), independente do historico. Alinha o custo com a pergunta ("existe estado recente?" e sobre 1 ponto, nao sobre N).
2. **Escrita atomica:** grave em `.tmp` e `mv -f`/`Move-Item -Force`. Sem isso o leitor pode pegar o arquivo no meio da escrita.
3. **Auto-poda no produtor:** ao gravar, remova os irmaos antigos. Assim pilhas legadas drenam sozinhas no proximo evento -- sem limpeza manual nem reinstalar N copias de hook.
4. **Corrija na fonte compartilhada, nao nas N copias.** Se o leitor e gerado por template (1 copia) e o produtor e 1 script, mude ali -- hooks por-projeto sao N lugares pra divergir. Depois da correcao do produtor + poda, as copias antigas ficam O(1) sozinhas (N=1).
5. **Meca antes de "otimizar".** Trocar o laco por `ls -t` teria economizado 10% (o custo era o `stat` em N, nao o laco) -- a medicao refutou a hipotese obvia.

**Ref:** canon Percus, hook R11 pre-commit, 2026-07-20. tiatendo chegou a **2026 marcadores** -> commit pendurava **148s** -> travou o projeto. Paid Midia (1399), Plexco Tasks (1123), Plexco Coach (844) estavam no mesmo caminho. Fix: `latest.jsonl` + escrita atomica + auto-poda no wrapper + leitura de path fixo no template/checks. Resultado: 148s -> **1,1s** (127x).
