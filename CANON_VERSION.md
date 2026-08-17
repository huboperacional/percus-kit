# Canon Percus — versão atual

**Versão canônica em `huboperacional/percus-kit`:** `6.36.7`

> Esta versão refere-se ao **kit Percus completo** (canon `_Novo_Projeto/` + plugin `percus-review`).
>
> ⚠️ **A sincronização é por commit em `main`, NÃO por tag.** O texto anterior aqui dizia "sincronizados via tag" — medido em 2026-08-13, a última tag do repo é `v6.7.2` e o canon estava em `6.35.0`: o tagging morreu 28 versões atrás e este parágrafo apontava para um mecanismo que não existe mais. Quem quiser saber a versão de um commit lê o cabeçalho acima, não `git describe`. Retomar o tagging é decisão em aberto; enquanto não for retomado, este texto descreve o que realmente acontece.
>
> ⚠️ **O plugin INSTALADO (em `plugins/cache/`) pode ficar ATRÁS do canon-source — isso é ESPERADO para os GATES, e NÃO é esperado para os HOOKS.** O republish/retag do plugin foi descartado (decisão do operador, 01/07/2026), então o tooling novo é **repo-only**: os projetos continuam lendo o plugin em cache (hoje 6.28.0/6.29.0). Isso funciona para os **gates de commit**, que chegam via `v2/gates/instalar-gates.sh` (git hook self-contained, zero dependência de publicação).
>
> **Mas NÃO funciona para os hooks do plugin** (`PreToolUse`, `Stop`, `PreCompact`), e isso custou caro: o `hooks.json` invoca `${CLAUDE_PLUGIN_ROOT}/hooks/*.cmd`, e `CLAUDE_PLUGIN_ROOT` resolve para a pasta **instalada** — não para o kit. Medido em 2026-07-30: três guardas de `PreToolUse` estavam **mortas respondendo verde** e o conserto no repo não as alcançava. Correção da regra: conserto em `plugin/percus-review/hooks/` **exige publicação** (bump → push → `/plugin marketplace update` → `/plugin update`). Copiar arquivo para dentro de `plugins/cache/` à mão **não é suportado** — o próximo update sobrescreve, o cleanup de 14 dias apaga versão órfã, e o `installed_plugins.json` passa a mentir sobre o estado real.
>
> **Publicacao agora e automatica (2026-07-30):** `autoUpdate: true` no `percus-tools` dentro de
> `extraKnownMarketplaces`. Auto-update vem ligado por padrao apenas para marketplaces oficiais da
> Anthropic; para marketplace proprio como este, vem **desligado** — foi por isso que a versao
> instalada ficou 26 dias atras sem ninguem desligar nada. Com a chave ligada, cada maquina busca a
> versao nova sozinha depois que a sessao sobe (atraso aleatorio de ate 10 min) e carrega no proximo
> launch, ou na hora com `/reload-plugins`. **O que continua manual: o `git pull` do proprio kit** —
> auto-update cuida do plugin em cache, nao da copia de trabalho que o `PERCUS_CANON_DIR` aponta e de
> onde os gates de commit leem.
>
> Resumindo o que continua valendo: `plugin/percus-review/plugin.json` (source) acompanha esta versão; a pasta em cache reflete o último republish. Para **gates**, ficar atrás é legítimo. Para **hooks**, ficar atrás é defeito operacional e precisa de publicação.

---

## Changelog v6.36.7 — 2026-08-17

**O hook passou a gravar a própria auditoria do R20 — e o achado da 6.36.6 que motivou isto estava
metade certo.**

**O que quebrou, medido:** o push desta manhã saiu **07:37:49** (reflog de `origin/main`) usando a
autorização em lote `ef675b38`, e o `.percus/autorizacoes-usadas.jsonl` continuou terminando em
**2026-08-16 15:57**. O `registrar-uso-autorizacao.ps1` nunca foi chamado. O spec de 2026-08-06
manda registrar todo uso (item 4 do "Comportamento do agente"), mas isso era **promessa em prosa,
sem guarda** — e quebrou do jeito que promessa sem guarda quebra: calada, e descoberta por acaso
duas horas depois.

🔑 **A correção inverte de quem é a responsabilidade.** O hook já roda em toda ação externa, já lê o
arquivo de autorização e já conhece o comando. Gravar a linha **ali**, no ramo que aceita a
autorização, torna o log completo **por construção** em vez de por memória do agente. O
`registrar-uso-autorizacao.ps1` continua existindo — é o único caminho para registrar um uso que não
passou pelo hook (push manual do operador, perna Unix) — mas deixou de ser a única fonte.

⚠️ **`PreToolUse` roda ANTES do comando**, então a linha registra **autorização concedida**, não
execução concluída. Por isso ela carrega `origem: "hook"`, distinguindo das linhas que o script
escreve depois do fato (`origem: "script"`). Chamar as duas coisas de "uso" no mesmo campo faria o
log afirmar mais do que sabe.

**O que NÃO mudou, e é decisão explícita:** o lote continua lote. A 6.36.6 propôs "consumir no
`registrar-uso` ou encurtar a janela" — mas consumir desfaria a decisão de 2026-08-06, onde
"autorização **em lote**" era o objetivo declarado ("o mesmo arquivo libera qualquer uma delas até
expirar"), nascida do operador estar batendo em rate limit do GitHub. Confirmado com o operador em
2026-08-17: o lote fica. Tem teste de regressão para isso — duas ações na mesma janela geram duas
linhas e as duas passam.

🔎 **A evidência citada na 6.36.6 estava mal atribuída, e achar o culpado deu o defeito de verdade.**
A 6.36.6 disse que "o teste do `external-action-guard` ficou vermelho com a autorização viva".
Medido: com a autorização viva, os 19 casos de `external-action-guard.tests.ps1` passam — eles
fazem `Push-Location` para pasta temporária. Quem ficava vermelho era
**`hardening-2026-05-18.tests.ps1:100`**, o único teste do hook **sem** isolamento: ele rodava o
hook com `cwd` = raiz do repo, então lia o `.percus/acao-externa-autorizada.json` **real** do
checkout. Números da manhã: **361/1 com autorização viva, 362/0 depois de expirar**, e reprodução
controlada numa cópia do repo (autorização plantada → o mesmo teste volta a cair).

**Por que isso deixou de ser curiosidade e virou pré-requisito:** com o hook gravando, rodar a suíte
com uma autorização viva passaria a **escrever linhas de teste no log de auditoria real do repo**.
Teste que não isola não estava só medindo a hora do dia — ia passar a poluir a trilha que esta
versão existe para tornar confiável.

⚠️ **A reprodução foi feita numa CÓPIA, nunca no checkout.** Plantar uma autorização viva no repo
real abriria o portão R20 de verdade, e o checkout é compartilhado entre sessões (ver
`checkout-compartilhado-entre-sessoes`): a autorização plantada "para testar" valeria para a sessão
do lado.

**Falha ao gravar BLOQUEIA, depois de 3 tentativas.** Decisão do operador: a auditoria é parte do
gate, não contabilidade à parte. Um push bloqueado se resolve com um comando; uma linha que nunca
existiu é invisível para sempre. As 3 tentativas com backoff curto existem porque o checkout é
compartilhado e append concorrente pode esbarrar em lock de milissegundo — sem elas, colisão viraria
bloqueio de ação legítima.

⚠️ **A mensagem é PRÓPRIA, não o `BLOCK` genérico do fim do script.** Antes desta versão a exceção
do append caía no `catch` local e o hook terminava dizendo *"acao externa publica requer aprovacao
explicita do operador"* — **mentira**: a autorização era válida e o operador tinha autorizado. A
mensagem mandava reautorizar um problema que não era de autorização.

🔑 **E o teste de paridade achou uma divergência que já estava lá:** `Add-Content -Encoding UTF8`
grava **com BOM no 5.1** (runtime real do hook) e **sem BOM no pwsh 7**. Hook e script escrevem no
**mesmo** `.jsonl`, então o arquivo acumularia linhas de encodings diferentes — e BOM no meio de um
append-only não é marcador de arquivo, é **byte de dado no meio de uma linha**. Os dois passaram a
usar `[IO.File]::AppendAllText` + `UTF8Encoding($false)`.

É `#regra-duplicada-ps1-sh` pela quarta versão seguida, e desta vez a guarda seguiu a regra prática
do próprio verbete: **o teste compara as duas cópias** (roda os dois escritores sob `powershell.exe`
5.1 real e confere BOM, quebra de linha, conjunto de campos e `motivo` acentuado). Dois testes
independentes, um por escritor, teriam ficado verdes lado a lado com a divergência intacta — sob
`pwsh` os dois escrevem sem BOM, então a suíte é cega para a classe por construção.

**Mutação confirmada em cinco eixos:** remover o append (derruba 2), registrar sem olhar a idade
(derruba a guarda de expirada), registrar no caminho do `PERCUS_EXTERNAL_OVERRIDE` (derruba a guarda
do override — o log audita o lote, não o override, que é outro mecanismo), registrar antes de checar
se há autorização (derruba a guarda de "sem autorização"), e trocar CRLF por LF no script (derruba a
paridade).

**Ficou de fora, declarado:** o `external-action-guard.sh` é stub fail-closed que só conhece
`PERCUS_EXTERNAL_OVERRIDE` — ele **nunca** toma o ramo da autorização em lote, então não tem uso a
registrar. Não é gap de paridade novo; é a mesma exceção de segurança já declarada na R20.

**Continua em aberto:** o risco estrutural de 2026-08-06 (o agente cria o arquivo que o hook confia)
é o mesmo de antes — esta versão torna o **registro** confiável, não a **concessão**.

🔎 **Achado NÃO corrigido aqui, e é a MESMA classe pelo outro lado:** o caso
`percus-gate.sh — roda limpo no canon de verdade` lê o **índice real** do repositório. Na hora deste
commit ele estava vermelho porque **outra sessão** tinha hooks de kit staged sem bump de versão — o
gate estava certo, e estava falando do trabalho dela. Onde
`hardening-2026-05-18.tests.ps1` dependia do `cwd` real, este depende do **índice** real; em ambos o
veredito do teste é função do estado da máquina, não do código. Num checkout compartilhado (cenário
documentado neste projeto) isso é vermelho intermitente que não aponta para quem o causou. Merece
decisão própria — não corrigido aqui porque mexer no gate no mesmo commit que mexe no R20 misturaria
duas frentes.

⚠️ **E ele se provou sozinho durante esta própria versão:** estava vermelho enquanto o bump não
estava no índice, e ficou **verde** assim que o `git add` do bump entrou — **sem uma linha de código
mudar entre as duas rodadas**. Um teste cujo veredito vira ao sabor do `git add` de outra pessoa não
afere o gate; afere o índice. Suíte final: **370/0**.

🔎 **Achado sobre o próprio R11, e ele é o mais grave desta versão:** o fact-check (F3) filtrou
**os três** findings desta review como `INFUNDADO`, com a razão *"sem path verificável ou arquivo
ausente"*. Um deles estava **certo**: o backoff de 50/100ms do retry acima, corrigido para 100/200/400
por causa dele. O texto bruto do finding trazia o caminho **completo e correto**
(`plugin/percus-review/hooks/external-action-guard.ps1`); foi o pipeline que o truncou para
`external-action-guard.ps` — sem o `1` — e então não achou o arquivo e concluiu "não verificável".

**A consequência é a pior possível para uma guarda:** o F3 existe para filtrar alucinação, e aqui ele
descartou um achado real **silenciosamente**, apresentando-o como infundado. Filtro que erra para o
lado de descartar transforma review em teatro — e neste caso só não custou nada porque o finding foi
lido no `.jsonl` bruto em vez do relatório. Não corrigido aqui (é no pipeline de fact-check, outra
frente); registrado em `#fact-check-trunca-path-e-descarta-finding-valido`.

⚠️ **O R11 desta versão rodou com DUAS pernas, não três — e isso é achado, não nota de rodapé.** A
perna Groq voltou `"status": "error"` / `404 (Not Found)` para `llama-3.3-70b-versatile`: o modelo foi
**decomissionado** e o id morto está hardcoded no kit. Pior que a queda: o wrapper imprimiu
`orchestrator Llama executado` do mesmo jeito — a linha de status reporta que **rodou**, não que
**funcionou**, então quem lê o stdout conclui 3/3. Só o `.jsonl` do `council-log` conta a verdade.
Conserto é troca de família de modelo em 9 arquivos, frente própria, fora desta versão.

**A perna Cross-Claude achou quatro coisas, e três mudaram o código:**

- **O backoff que eu tinha acabado de "corrigir" mentia.** O comentário dizia 700ms; o loop só dorme
  quando `$tentativa -lt 3`, então o `400` nunca era dormido e o total real era **300ms**. O revisor
  mediu rodando o laço. Agora é `200 * $tentativa` — 200 e 400, **600ms reais** — e o comentário diz
  o número que o código entrega. Duas rodadas de review para calibrar um `Start-Sleep`, porque a
  justificativa da decisão dependia da janela ser o que estava escrito.
- **O retry não tinha teste do que ele existe para fazer.** O caso de falha cobria "falha sempre"
  (bloqueia); faltava "falha, tenta de novo, funciona" — quebrar o laço deixaria a suíte verde.
  Caso novo destrava o arquivo no meio do voo; mutação (`-le 3` → `-le 1`) derruba só ele.
- **O teste de paridade só comparava um lado com o outro**, sem valor absoluto. Os dois regredindo
  **juntos** passariam — plausível justamente porque um foi copiado do outro, que foi como o BOM
  entrou nos dois. Agora ancora em `13,10` e no conjunto exato de campos **antes** de comparar os
  lados. Era a própria doença do `#regra-duplicada-ps1-sh` sobrevivendo dentro da guarda contra ela.
- E contei "6 casos novos" onde o diff tem 8.

**Segunda rodada de R11 sobre os próprios consertos, mais quatro — e o primeiro é um vazamento que
EU introduzi:**

🔑 **A gravação automática transformou o log de auditoria em depósito de segredo.** Até a 6.36.6 o
agente escolhia o que passar para o `registrar-uso`; agora **todo** comando autorizado vai para o
disco sem ninguém decidir, e o arquivo sobrevive à sessão. `git push https://user:token@host` é a
forma mais comum, e o token ficava em texto claro. Este é o custo escondido de mover uma promessa
para dentro de uma automação: o que era ocasional e deliberado virou sistemático. Os dois escritores
passam a mascarar credencial em URL, par `chave=valor` sensível e header `Authorization`.

⚠️ **E a máscara nasceu duplicada, porque não dá para compartilhar função entre o hook e o script:**
o hook roda a partir do plugin **instalado** (`plugins/cache/...`) e o script a partir do **kit** —
raízes diferentes, `dot-source` seria dependência quebrada. Então o teste de paridade passa o
**mesmo comando com credencial** pelos dois e exige máscara idêntica. Mutação removendo a máscara só
de um lado derruba exatamente esse teste.

- **As guardas de "não registra" não conferiam o exit code.** "Não gravou log" também é verdade
  quando o hook quebrou por outro motivo — e no caso do `PERCUS_EXTERNAL_OVERRIDE` o teste passaria
  com o override **regredido e bloqueando**. Três testes ganharam asserção de código de saída.
- **O teste de falha transitória podia dar falso-VERMELHO**, ao contrário do que o comentário dele
  afirmava. Com startup rápido do `pwsh` a 3ª tentativa caía antes da remoção do bloqueio. Refeita a
  conta: com remoção em 250ms e última tentativa em `startup+600`, ela é sempre posterior — para
  qualquer startup. O comentário agora mostra a aritmética em vez de alegar a conclusão.
- O quarto era `mock-scan-pre-commit.sh` (fail-open em `rc` inesperado do `grep`), arquivo de outra
  frente — repassado, não corrigido aqui.

🔎 **E o defeito do fact-check reproduziu, determinístico:** na segunda review, **4 de 4** findings
filtrados como `INFUNDADO`, todos com o caminho truncado no mesmo lugar (`.ps` por `.ps1`,
`.tests.ps` por `.tests.ps1`). Duas medições independentes, mesmo mecanismo — não é aleatório, é o
extrator. Todos os quatro eram legítimos e três viraram código.

**Terceira rodada — e a máscara que eu tinha "consertado" protegia a forma errada.** O Cross-Claude
rodou 12 formas reais de credencial contra ela, medindo em vez de opinar. Resultado: mascarava
`https://usuario:token@host` (a variante rara) e deixava passar **inteiro**
`https://TOKEN@host` — token como usuário, que é a forma **mais comum** de `git push` com PAT do
GitHub. Também escapavam `--token VALOR` (sem `=`), `GH_TOKEN=...` (o `\b` falha porque `_` é
caractere de palavra), `curl -u user:senha`, `X-Api-Key:`, `PRIVATE-TOKEN:` e `{"password":"x"}` do
JSON. E `Authorization: token <PAT>` mascarava a palavra *"token"* deixando o PAT logo depois —
mira errada, não ausência de mira.

⚠️ **Máscara parcial é pior que máscara nenhuma**, porque produz confiança: quem lê "os comandos são
mascarados" para de olhar. As quatro regras foram recalibradas contra as 12 formas medidas —
**0 vazamentos de 12** — com **viés declarado: na dúvida, mascara demais.** Log de segurança troca
fidelidade por contenção de bom grado; destruir uma palavra de prosa custa quase nada, vazar um PAT
custa a conta. Continua sendo blocklist, portanto best-effort por natureza: cobre o que foi medido,
não promete o resto.

O `\S+` do valor virou `[^\s"']` de carona — ele comia a aspa de fechamento e gravava um comando
sintaticamente diferente do que rodou. E o teste de paridade, que exercitava **só** a regra de URL,
passou a levar três famílias de credencial num comando só: as outras regras estavam sem paridade
aferida, que é o buraco exato que ele existe para fechar.

**Quarta rodada — a máscara cobria o ARQUIVO e deixava o outro canal aberto.** Ela era aplicada
dentro do ramo autorizado, então o `.jsonl` saía limpo enquanto as mensagens de `BLOCK` continuavam
imprimindo o comando **cru** no stderr, e o `registrar-uso` ecoava o original no stdout. Stderr de
hook e stdout de script vão parar em log de sessão e de CI — mascarar um canal e deixar o outro não
é máscara, é sensação. A máscara subiu para **antes de qualquer saída**, e há guarda para os dois
caminhos de bloqueio (mutação que volta a imprimir o cru derruba as duas). De carona, entrou a flag
curta colada (`curl -uusuario:senha`).

**Ficou de fora, declarado — duas lacunas medidas, não presumidas:**

- A máscara **over-mascara prosa** que contenha `authorization:` (`--body "isto requer
  authorization: veja o doc"` perde a palavra *"veja"*). Custo aceito do viés, e preferível ao
  inverso.
- A regra 2 corta o valor em `&` e `,`, então um segredo que **contenha** esses caracteres vaza da
  parte cortada em diante. Manter `&` como delimitador preserva a legibilidade de query string
  (`?api_key=***&q=1`); alargar protegeria mais e destruiria o resto da URL. Trade-off explícito.

Blocklist não fecha. O que fecharia é não gravar o comando — e aí a auditoria perde exatamente o que
a torna útil.

Suíte: **378 Pester + 10 pytest, tudo verde** (16 casos novos, 35 no `external-action-guard`).
**Oito mutações confirmadas**, incluindo a que remove a máscara de um só lado e a que volta a
imprimir o comando cru na mensagem de bloqueio.

**Quatro rodadas de R11 nesta versão, 18 achados tratados** — e o padrão que emerge é desconfortável:
**oito dos que viraram código vinham de findings que o fact-check tinha carimbado como `INFUNDADO`**.
A guarda que existe para filtrar alucinação estava filtrando o trabalho bom, e só não custou caro
porque o `.jsonl` bruto foi lido à mão. Se houver uma prioridade para a próxima versão, é essa.

🔎 **Achado estrutural do próprio R11, encontrado tentando commitar isto:** o `pre-commit-check`
exige review com **no máximo 5 minutos**, e a review deste diff levou **mais de 10** (o wrapper
estourou um timeout de 10 min na primeira tentativa). Para qualquer mudança grande, portanto, é
**impossível** ler os achados e commitar dentro da janela — o único caminho que passa é encadear
`review && commit` mecanicamente, que é exatamente o oposto do que o R11 quer. O TTL foi calibrado
para diff pequeno e vira, no diff grande, um incentivo a não ler. Merece decisão própria: TTL
proporcional ao tamanho do diff, ou janela maior com invalidação por mudança de conteúdo em vez de
por relógio.

**Onde eu parei, e por quê:** as rodadas 1–2 acharam defeito de mecanismo (perda de auditoria,
divergência de encoding, retry sem cobertura). A 3ª e a 4ª acharam vazamento de credencial — mais
graves, e vieram porque a mudança **criou** superfície nova. Paro aqui: a máscara está calibrada
contra 12 formas medidas com 0 vazamentos, os dois canais de saída estão cobertos, e as duas lacunas
restantes estão declaradas com o trade-off explícito. Continuar refinando blocklist tem retorno
decrescente — R11 exige **tratar** os achados, não zerá-los.

## Changelog v6.36.6 — 2026-08-16

**Caixa de entrada de conhecimento — sessões concorrentes param de colidir no `COMO_RESOLVER.md`.**
Etapa 1 de 2 (a etapa 2, o split em um-arquivo-por-verbete, fica para depois e continua opcional).

**O problema, medido:** o `COMO_RESOLVER.md` tem 335 verbetes num arquivo de **912 KB**, e toda sessão
de todo projeto escreve nele. O git resolve conflito em **arquivo**, então duas sessões escrevendo
lições sobre assuntos completamente diferentes colidem assim mesmo. Nesta mesma data isso custou:
um commit levaria junto o rascunho inacabado de outra sessão, o gate barrou um commit legítimo, e
uma sessão chegou a classificar como "trabalho de outra sessão" um verbete escrito pela própria.

**A caixa:**

```
conhecimento/entrada/resolver/<slug>.md  ->  COMO_RESOLVER.md
conhecimento/entrada/fazer/<slug>.md     ->  COMO_FAZER.md
```

Um verbete por arquivo, formato idêntico ao de sempre, e o **nome do arquivo é o slug** da âncora —
não é estética: é o que torna o merge determinístico hoje e o split mecânico depois. Arquivos
diferentes não dão conflito de git, então a escrita fica livre de colisão **sempre**.

**`scripts/mesclar-conhecimento.ps1`**, chamado pelo `checkpoint`, anexa cada verbete e insere a
linha de índice sozinho.

🔑 **A regra que sustenta o desenho: se o monólito já está modificado na árvore — outra sessão
mexendo — o mesclador NÃO mescla. Ele ADIA**, e as entradas ficam na caixa para o próximo
checkpoint, saindo com código **0**, porque adiar não é erro. Isso só é aceitável porque a caixa é
**durável**: sem ela, adiar significava perder o verbete ou travar o commit. É a inversão que faz o
mecanismo funcionar — colisão vira adiamento, e adiamento é de graça. Git indisponível ou pasta que
não é repo também contam como "ocupado": num script que reescreve a base inteira, desconhecido não
é sinal verde.

Entrada **inválida** também fica na caixa (descartar perderia o verbete), mas o script sai != 0 para
denunciar — e **uma entrada podre não retém as saudáveis**.

**Gate (`percus-gate.sh` bloco 3c):** a caixa tem bloco **próprio**, não um glob a mais nos blocos
2/3. Motivo: a checagem 2 exige que a âncora apareça como `(#ancora)` no **mesmo arquivo**, o que num
arquivo de um verbete só nunca é verdade — estender o glob reprovaria **toda** entrada válida. O
bloco novo afere um verbete por arquivo, slug == nome do arquivo, `tags:` presente e fence fechado.
Entrada fora de gate é entrada que nasce invisível, que é exatamente o que a caixa deveria evitar.

**Visibilidade — o risco real desta mudança.** `consult-knowledge` e R23 passam a mandar consultar a
caixa **junto com** o monólito. Sem isso, esta versão recriaria na hora o problema do commit
`9cecfdb` ("8 entradas de produção, e 5 delas estavam INVISÍVEIS").

⚠️ **Defeito corrigido de carona, e ele era grave:** a skill `consult-knowledge` instruía *"Leia o
arquivo inteiro (`COMO_RESOLVER.md` é pequeno e cabe no contexto)"*. Era verdade quando foi escrita e
hoje é falso por duas ordens de grandeza — **~230k tokens**. A skill mandava o agente fazer algo que
não cabe no contexto, o que na prática empurrava todo mundo para o `grep` literal que a própria skill
proíbe no parágrafo de cima. Agora: leia o **Índice**, depois o verbete escolhido (~3 KB).

**Testado, e testado no arquivo de verdade.** 9 casos comportamentais sobre fixture (merge, roteamento
por pasta, adiamento com árvore suja, slug divergente, `tags:` ausente, slug duplicado, caixa vazia,
uma podre não retendo as boas, CRLF preservado) + 5 casos no gate. Mutação confirmada em quatro
eixos. **E foi rodado de verdade contra o `COMO_RESOLVER.md` real**, com estes dois verbetes desta
sessão: **58 adições, 0 remoções**, 12362 quebras de linha todas `\r\n`, zero LF solto, sem BOM.

⚠️ **CRLF não é detalhe:** o arquivo é CRLF e um mesclador que normalizasse para LF produziria um
diff de 12 mil linhas no primeiro uso. Tem teste só para isso.

**Cinco defeitos achados pelo próprio R11 revisando esta versão — e um deles atacava a premissa
central do desenho:**

1. **`Remove-Item` da entrada acontecia ANTES de gravar o monólito.** Se a gravação falhasse (disco,
   permissão, lock), o verbete se perdia — trocando colisão de git por **perda**, que é o único
   desfecho pior que o problema original. A durabilidade da caixa é o que torna "adiar" de graça;
   sem ela o desenho inteiro cai. Agora grava uma vez e só então remove; se a gravação falhar, as
   entradas ficam e o script diz "nada foi perdido". Teste força o caso deixando o destino
   read-only.
2. **Gate e mesclador discordavam sobre fence.** O gate ignora `## {#slug}` dentro de bloco de
   código; o mesclador não. Um verbete com exemplo de markdown passava no gate e era recusado no
   merge. Gate que aprova o que o passo seguinte recusa é pior que os dois errarem juntos: o commit
   passa e o checkpoint quebra depois.
3. **Blockquote consumia a janela do `tags:` no mesclador.** O awk do gate pula linhas `>` **sem**
   incrementar o contador — e o comentário dele registra que sem isso ele acusava "sem tags:" um
   verbete que TEM tags, barrando commit legítimo. O mesclador reintroduzia exatamente esse bug.
   Agora espelha a ordem do awk: fence, blockquote, título, contador.
4. **Gravava o monólito mesmo sem ter mesclado nada**, e o join era CRLF fixo — num arquivo LF isso
   normalizaria o arquivo inteiro. Agora só grava se algo mudou, e a quebra de linha é **detectada
   do arquivo** em vez de assumida.
5. **O gate não checava slug duplicado**, então o checkpoint falhava depois do gate ter aprovado.
   Passou a checar no gate também.

Mutação confirmada nos quatro eixos do mesclador (inclusive o de durabilidade, que derruba 5 testes
quando revertido).

**Segunda rodada do R11, mais três — e o primeiro é a MESMA classe de novo:**

6. **Gate e mesclador discordavam sobre a âncora.** O awk usava `/^## .*\{#/`, que aceita
   `## Título {#slug} sobra depois` e recusa `##<TAB>Título` — o mesclador faz o inverso nos dois
   casos. Padrão agora é estrito e idêntico dos dois lados: `##` + espaço **ou tab**, âncora
   **fechando** a linha, com mensagem própria para o caso do texto sobrando.
7. **A inserção de índice duplicava a última linha quando o índice era a última linha do arquivo.**
   `$linhas[($fim+1)..($Count-1)]` vira `Count..Count-1`, e no PowerShell **range decrescente conta
   para trás**: devolve `@($null, último)`. Só acontece em arquivo sem quebra de linha final — e a
   primeira versão do teste tinha quebra final, então passava **sem exercitar o bug**. Corrigido o
   teste antes do código; com a reprodução correta o índice vinha com 2 linhas em vez de 1.
8. **Falha ao remover a entrada depois do merge saía como exceção crua.** O verbete já estava no
   monólito e continuava na caixa, e o próximo checkpoint acusaria slug duplicado sem explicar a
   causa. Agora a mensagem diz o que já aconteceu e o que fazer.

**Terceira rodada do R11, mais quatro — e o primeiro é CRLF outra vez, do outro lado:**

9. **Os `awk` do bloco 3c não toleravam `\r`.** No Git Bash o CR é absorvido e os testes passam;
   em bash nativo/CI com working tree CRLF (`core.autocrlf` desligado), o `$` do awk não casa e
   **toda entrada válida** seria denunciada como malformada. O mesclador já usava `\r?$` — era a
   mesma divergência gate↔mesclador, agora por quebra de linha. Agora os três `awk` recebem o
   arquivo por `tr -d '\r'`.
10. **A checagem de duplicata não pulava fence**, ao contrário de todo o resto do bloco 3c: um
    verbete que **cita** `{#slug}` como exemplo dentro de ``` bloqueava uma entrada nova legítima
    com aquele slug.
11. **Mensagens operacionais saíam por `Write-Host`** — que no PS 5.1 escreve no host e pode não
    atravessar o stdout quando o processo é capturado. É a lição do verbete
    `#teste-in-process-nao-captura-console-error`, escrito **nesta mesma versão**, e o script a
    violava. Agora `[Console]::Out.WriteLine`.
12. **A skill dizia "~3 KB" para Índice + verbete.** Medido: o Índice sozinho tem **339 linhas /
    ~45 KB (~13k tokens)**; verbete típico, 3–6 KB. Errado por 15×, e subestimar custo de contexto
    numa skill que existe para reduzir custo de contexto reintroduz o problema pela porta dos
    fundos. Corrigido com os números reais e orientação de quando ler o índice inteiro.

**Quarta rodada do R11, mais três — todas gate↔mesclador, e uma delas contra um item deste próprio
changelog:**

13. **A correção do item 10 só tinha sido feita no mesclador.** O gate continuava fazendo
    `grep -qF "{#slug}"` no monólito cru, sem pular fence. Declarar corrigido de um lado e deixar o
    outro para trás é o modo mais fácil de um changelog mentir. Agora o gate passa o destino por
    um `awk` que descarta fence antes do `grep`.
14. **`##` sem âncora no corpo:** o gate acusava, o mesclador ignorava. Alinhado na direção
    **segura** — o gate estava certo. Verbete usa `**Negrito:**` para seção, nunca `##`; um `##`
    solto viraria **verbete novo** depois do merge, sem âncora e sem `tags:`, e o gate seguinte
    barraria o arquivo inteiro sem que ninguém entendesse por quê.
15. **Área desconhecida em `entrada/` passava no gate.** O mesclador só processa `resolver` e
    `fazer`, então um `entrada/qualquer-coisa/x.md` seria aprovado e **ignorado para sempre** —
    conhecimento escrito e invisível, o cenário exato que o bloco 3c existe para impedir.

**Quinta rodada, mais três:**

16. **Título vazio (`## {#slug}`)** era aceito pelo gate e recusado pelo mesclador, cujo regex exige
    pelo menos um caractere de título — sem título não há como montar a linha de índice.
17. **Duplicata divergia na caixa alta/baixa:** `-match` do PowerShell é case-insensitive,
    `grep -F` é case-sensitive. Alinhado na direção segura (ambos recusam), porque âncora que
    difere só em maiúscula colide na renderização.
18. **Subpasta dentro de área válida era invisível dos DOIS lados.** O glob `entrada/*/*.md` do
    gate e o `Get-ChildItem` não-recursivo do mesclador ignoravam `entrada/resolver/sub/x.md` em
    silêncio — escrito e invisível **para sempre**. Agora o gate afere a **posição** antes do
    conteúdo: qualquer `.md` fora de `entrada/<area>/<slug>.md` é violação (exceto o `LEIA-ME.md`).

⚠️ **Dois defeitos meus na correção do 18, ambos clássicos de shell:** `-mindepth`/`-maxdepth` são
opções **globais** do `find`, não predicados — dentro de `\( \)` não filtram nada, e a primeira
versão acusava até o próprio `LEIA-ME.md`. E `find | while` roda em **subshell**, então o `FAIL=1`
de dentro do `violacao` se perderia: o gate acusaria e ainda assim sairia 0. Por isso o laço é `for`.

🔎 **Achado de ambiente, virou verbete:** `grep -iF` **aborta com SIGABRT** (rc=134) neste build do
Git Bash — cada flag sozinha funciona, é a combinação que quebra. Como a contagem vinha de `$( )`,
o abort virou string vazia e só apareceu duas camadas depois como
`[: : integer expression expected`. Contorno portátil: baixar a caixa dos dois lados com `tr` em vez
de pedir `-i` ao grep. Registrado em `#grep-if-aborta-git-bash`.

**Sexta rodada, mais duas — as duas sobre o que conta como âncora:**

19. **Menção inline a `{#slug}` em prosa contava como âncora existente**, bloqueando entrada nova
    legítima. E isso não é hipótese: a base de conhecimento **fala de si mesma** o tempo todo — o
    verbete `#grep-if-aborta-git-bash`, escrito nesta versão, cita `{#slug}` em prosa. Agora âncora
    é só o que está em **linha de título**, fora de fence, dos dois lados.
20. **Título começando com `{` divergia**: o gate exigia que o primeiro caractere não fosse `{`
    (restrição que eu tinha introduzido para barrar título vazio), e o mesclador aceitava. Alinhado
    para "≥1 caractere antes da âncora final", que barra `## {#slug}` e aceita `## {chave} ... {#slug}`.
    Junto: o gate extraía **todas** as ocorrências de `{#...}` da linha e o mesclador só a final,
    então `## Usar {#fake} e {#slug}` virava 2 âncoras de um lado e 1 do outro.

**Sétima rodada, mais quatro — e aqui a severidade já tinha caído para entrada exótica:**

21. **Word splitting no `for x in $(find ...)`** partia caminho com espaço em vários argumentos.
    Corrigido fixando `IFS` só em quebra de linha.
22. **Separador `---` duplicado** se o monólito já terminasse em `---`. Ao consertar, errei de
    novo: `(?m)^---$` casa **qualquer** separador do meio do arquivo, então o script nunca
    acrescentaria o dele. A checagem tem de olhar a **última linha**, não o arquivo.
23. **Caixa com entrada e monólito de destino ausente** era aprovada pelo gate e falhava no
    mesclador. Ao fechar isso, quatro testes existentes ficaram vermelhos — e estavam certos em
    ficar: o `New-CaixaRepo` **nunca criava o monólito**, ou seja, o fixture testava um estado que
    não existe em repo real. Corrigido o fixture, não a regra.
24. **Linha `##` pelada** (sem título, sem âncora, sem espaço) não era pega por **nenhum** dos dois
    lados — não era divergência, era lacuna compartilhada. Mesclada, viraria título vazio no
    monólito, denunciado só por um gate posterior e sem explicar a causa.

**Oitava rodada, mais uma — e é BOM, pela quarta vez nesta sessão:**

25. **Entrada gravada com BOM divergia.** Editor do Windows grava `.md` com BOM sem avisar; o
    `ReadAllText(UTF8)` do mesclador descarta o BOM sozinho e aceita, enquanto o `awk` do gate via
    `\xEF\xBB\xBF## Título`, não casava `^##` e rejeitava com "achei 0 títulos". As quatro
    passagens do bloco 3c agora tiram o BOM com `sed '1s/^\xEF\xBB\xBF//'` antes do `tr`/`awk`.
    ⚠️ **Não use `tr -d` para isso:** `tr` opera em **bytes** e apagaria `\xEF`/`\xBB`/`\xBF` em
    qualquer posição, corrompendo UTF-8 legítimo. `sed` só na primeira linha, só no início.

**Ficou de fora, declarado:** o `LEIA-ME.md` e a skill listam `**Ref:**` como parte do formato, mas
nem o gate nem o mesclador o exigem. É decisão de política (tornar o gate mais estrito ou afrouxar
o texto), não defeito — fica para o operador.

**Oito rodadas de R11 nesta versão, 25 defeitos**, e o padrão dominante tem nome: sempre que uma
regra existe em dois lugares (gate e mesclador, `.ps1` e `.sh`), a divergência **não** aparece nos
testes de nenhum dos dois lados — ela só aparece quando alguém compara os dois. Foi o mesmo padrão
da 6.36.4 (`temperature` em três arquivos) e da 6.36.3 (tabela de modelos duplicada). A conclusão
prática: **regra duplicada precisa de teste que compare as duas cópias**, não de dois testes
independentes — cada um deles fica verde sozinho.

**Escopo declarado:** o mesclador é só PowerShell, sem par `.sh`. Diferente dos providers do conselho
(que têm caminho bash real no `council-orchestrator.sh`), este script só é chamado pelo `checkpoint`.
Decisão explícita, não esquecimento.

🔎 **Achado NÃO corrigido aqui:** a autorização R20 **sobrevive ao uso**. Depois de `registrar-uso`,
o `.percus/acao-externa-autorizada.json` continua válido pelo resto da janela de 60 min — qualquer
ação externa seguinte passa sem nova aprovação. Apareceu porque o teste do `external-action-guard`
ficou vermelho com a autorização do push desta sessão ainda viva. Merece decisão própria: consumir no
`registrar-uso` ou encurtar a janela.

Suíte: **362 Pester + 10 pytest, tudo verde**, e o gate limpo no repo real.

**Onde eu parei, e por quê:** as rodadas 1–4 do R11 acharam `bug` que quebrariam na prática (perda
de verbete, guarda morta, commit liberado sem review). Da 5 em diante a severidade caiu para
`risco` em entrada exótica — título começando com `{`, âncora citada em prosa, `##` pelado. Fechei
esses porque eram baratos, e paro aqui: R11 exige **tratar** os achados, não zerá-los, e continuar
refinando bordas de markdown que ninguém escreve tem retorno decrescente. O que sobrar aparece na
próxima versão que tocar nestes arquivos.

**A caixa foi usada de verdade nesta própria versão**, três vezes: dois verbetes mesclados no
`COMO_RESOLVER.md` real (58 adições, 0 remoções) e um terceiro que o mesclador **adiou** — porque o
monólito estava modificado na árvore, exatamente a condição que a regra existe para tratar. O
mecanismo disparou sozinho, no arquivo de verdade, pelo motivo certo.

## Changelog v6.36.5 — 2026-08-16

**O `canon-version-check` estava morto há muito tempo, respondendo verde — e a causa é uma classe
que nenhuma guarda do kit cobria.** Era o achado que a 6.36.4 registrou como "em aberto, não
corrigido aqui". Investigado e fechado.

**O sintoma:** rodando sob `powershell.exe` 5.1 — que é o runtime real de todo hook — o
`canon-version-check.ps1` saía com
*"nao foi possivel extrair versao atual de CANON_VERSION.md - skip"* e **exit 0**. Sob `pwsh 7`
o mesmo hook funcionava perfeitamente e listava as três divergências de `system-prompt-*.md`.

**A causa raiz, medida:** no PS 5.1 o default de `Get-Content` é **ANSI (Windows-1252)**; no
pwsh 7 é **UTF-8**. O `CANON_VERSION.md` é UTF-8 **sem BOM** — como todo markdown deve ser. Então
o mesmo arquivo chega diferente nos dois runtimes:

```
pwsh 7 : # Canon Percus — versão atual        (correto)
PS 5.1 : # Canon Percus â€” versÃ£o atual      (mojibake)
```

E o regex do hook é `Vers[aã]o can[oô]nica em.*?` — **acentuado**. Contra o mojibake ele não casa,
`$currentVersion` fica `$null`, e o hook segue pelo caminho de skip. Controle que fecha o
diagnóstico: forçando a leitura em UTF-8 sob o mesmo 5.1, o regex casa e extrai `6.36.4`.

🔑 **Por que sobreviveu a todas as guardas — e esta é a lição:** o kit já conhecia a armadilha do
BOM, mas na forma *"o `.ps1` **fonte** sem BOM não **parseia** no 5.1"*, e a guarda
(`ps51-compat`) afere **parse**. Aqui o fonte parseia perfeitamente; o **dado lido** é que chega
corrompido. Mesma origem (default de encoding do 5.1), classe diferente, guarda diferente:

| classe | o que quebra | como se vê | conserto |
|---|---|---|---|
| conhecida (6.36.0/6.36.2) | `.ps1` **fonte** sem BOM | erro de parse | BOM no `.ps1` |
| **nova (esta)** | `.md`/`.json` **lido** | regex acentuado não casa, **silêncio** | `-Encoding UTF8` na leitura |

E **não dá para consertar botando BOM nos dados**: markdown não usa BOM, e JSON com BOM quebra
parser alheio. Quem **lê** é que tem de declarar o encoding.

**Alcance real, não hipotético:** 9 chamadas de `Get-Content` sem `-Encoding` em 4 hooks
(`canon-version-check`, `enforcement-health`, `external-action-guard`, `on-stop-check`) — todas
corrigidas. As de `enforcement-health` e `external-action-guard` liam **JSON**, que é UTF-8 por
especificação, então string acentuada dentro deles vinha corrompida em silêncio. O
`state-drift-check.ps1` **já** usava `-Encoding UTF8` desde antes: a lição existia em um hook e
nunca tinha generalizado.

**Segundo `Get-Content` do mesmo hook tinha o mesmo defeito** (linha 50, os `system-prompt-*.md`):
os três arquivos têm acento e não têm BOM, então mesmo que a versão fosse extraída, a comparação
rodaria sobre texto corrompido.

**Teste novo `hooks-leitura-utf8.tests.ps1` (2 casos), um deles COMPORTAMENTAL:** ele executa o
hook sob `powershell.exe` 5.1 de verdade e exige que a saída contenha `canon atual=` (anti-vacuidade
— hook que não roda deixaria o teste verde por saída vazia) e **não** contenha
`nao foi possivel extrair`. O segundo é estrutural: todo `Get-Content` em `hooks/` declara
`-Encoding UTF8`, com strip de comentário e de continuação de linha. Mutação confirmada: tirar o
`-Encoding` de uma linha derruba **os dois**.

⚠️ **A primeira versão dessa guarda aceitava o próprio bug de volta** — ela exigia só a *presença*
de `-Encoding`, e no PS 5.1 **`-Encoding Default` É o Windows-1252** que causou o mojibake
(`ASCII` é pior ainda). Apontado pelo R11 revisando esta versão; agora a exigência é do **valor**
`UTF8`, com mutação confirmada em `Default` e em `ASCII`. Guarda que aceita o defeito escrito por
extenso é pior que guarda nenhuma, porque parece cobertura.

Suíte: **323 Pester + 10 pytest, tudo verde.**

## Changelog v6.36.4 — 2026-08-16

**A perna bash do Cross-Claude estava 100% muda, e ninguém tinha visto porque o smoke usa
prompt trivial.** Esta versão nasceu da verificação que a 6.36.3 mandou fazer — rodar o conselho
com uma pergunta de design real, não com "responda PONG". A verificação achou quatro defeitos.

**1. `providers/cross-claude.sh` mandava `temperature` → HTTP 400 em toda chamada.**
`temperature is deprecated for this model`. Não é intermitente: **toda** invocação, em 1,2s. A
própria 6.36.3 tirou esse parâmetro do `fact-check.sh` e o `cross-claude.ps1` já trazia o
comentário explicando por quê — e o provider bash, que é o arquivo onde isso mais importa, ficou
de fora. O teste de paridade da 6.36.3 compara a tabela de **modelos** dos dois orquestradores,
então ficou verde enquanto o wrapper estava quebrado. Modelo igual, parâmetro diferente.

**2. `cross-claude.sh` tinha `MAX_TOKENS="4096"` e o orquestrador bash não passa `--max-tokens`.**
Quem manda no runtime bash é o default do arquivo. Com Sonnet 5 (thinking ligado) 4096 reproduz
`#resposta-vazia-teto-de-tokens`. Consertado junto: 16000, igual ao `.ps1`. O `MODEL` default
também estava em `claude-sonnet-4-6`. Prova depois do conserto: `status=ok`, 4455 chars,
**7652 tokens de completion** — acima do teto antigo, ou seja, os dois consertos eram necessários.

**3. Teto do DeepSeek: 8192 contra raciocínio medido de 6784–8192+.** A 6.36.2 trocou
`-pro` → `-flash` e não reavaliou o teto ao lado. O `-flash` raciocina, e `reasoning_tokens`
contam **dentro** de `completion_tokens`. Medido em 2026-08-16, três chamadas do **mesmo** prompt
em modo review: 6784, 7649 e 8192+. Ou seja, 8192 não era "pequeno demais" de forma limpa —
caía **no meio da faixa de variação**, e a mesma pergunta voltava `ok`, `truncated` ou `empty`
na sorte. Subiu para 16000 nos dois runtimes. O system prompt do modo `review` **dobra** o
raciocínio: com o system prompt default do provider a mesma pergunta gastou ~3100.

**4. Timeout de 60s já estava marginal.** Chamadas que **responderam** levaram 67s e 80s ainda no
teto antigo. Subir o teto sem subir o timeout apenas troca "resposta vazia" por "erro de rede" —
o defeito muda de nome e continua. 60s → 180s nos quatro arquivos, com paridade travada por teste.

**5. R11 liberava commit com review vazia — fail-open num gate.** O `deepseek-review.ps1` escrevia
`latest.jsonl`, que é **o arquivo que libera o commit**, incondicionalmente. Resposta vazia ou
cortada virava "commit aprovado" sem uma palavra. O lado bash já barrava vazia desde sempre
(divergência na direção contrária da usual), mas **nenhum dos dois** barrava **cortada** — que tem
texto, passa no teste de vazio, e chega com a conclusão faltando. Agora os dois classificam com
`Get-StatusResposta` e saem com código 3 **sem escrever o marcador**: sem marcador fresco, o hook
mantém o commit bloqueado. Nota medida: o `deepseek-review` **não** define `max_tokens` e o default
da API é ≥22494 tokens, então o teto não era o gatilho aqui — o fail-open era estrutural.

**6. Fail-open residual, apontado pelo próprio R11 ao revisar esta versão.** Barrar apenas
`finish_reason == "length"` deixava passar o campo **ausente** (resposta malformada) e qualquer
valor anômalo (`content_filter`, valor novo da API): ambos chegavam como "ok" e liberavam o commit.
Num gate, desconhecido conta como falha. Agora os dois runtimes exigem `stop`.
⚠️ **A correção óbvia estaria errada:** o reviewer sugeriu levar o `!= "stop"` para o
`_resposta.ps1` **compartilhado** — e isso reprovaria **toda** resposta do Cross-Claude, porque a
Anthropic devolve `end_turn`, não `stop`. O vocabulário de encerramento é por provider; a regra
mora no consumidor DeepSeek, não no classificador comum. Consertar a perna recém-consertada seria
o desfecho irônico desta versão.
(O mesmo review levantou um segundo ponto — `--temperature` removido do parser do `cross-claude.sh`
quebraria chamadores — que é **falso positivo**: nenhum chamador passa a flag, e o parser tem
`*) shift;;`, então flag desconhecida é ignorada, não é erro.)

**7. `Join-Path` com 3+ argumentos morre no PS 5.1 — e havia um HOOK assim.** Também apontado pelo
R11, revisando esta versão: o dot-source que eu tinha acabado de adicionar
(`Join-Path $PSScriptRoot ".." "providers" "_resposta.ps1"`) **quebra sob PowerShell 5.1**. O
parâmetro `-AdditionalChildPath`, que aceita mais de um child path, só existe do PS 6 em diante;
no 5.1 a chamada lança *"Não é possível localizar um parâmetro posicional que aceite o argumento
'providers'"*. Ou seja: o gate R11 que esta versão criou teria morrido no runtime que de fato roda
os hooks.

**Por que nenhuma guarda pegava, e esta é a lição:** o `ps51-compat` afere **parse**, e isso
parseia perfeitamente — quebra só em **runtime**. E a suíte roda em pwsh 7, onde funciona. Verde
nos dois lugares, morto no único que importa. Varredura do kit achou **3 sítios**, e um deles é
`hooks/canon-version-check.ps1` — **um hook**, portanto o caso real da classe, não hipótese.
Corrigidos os três (um child path por `Join-Path`), com teste varrendo `.ps1` de produção
(testes ficam de fora: só rodam sob Pester em pwsh 7). Mutação confirmada.

🔎 **Achado separado, NÃO corrigido aqui:** rodando `canon-version-check.ps1` sob 5.1 para conferir,
ele sai `0` com *"nao foi possivel extrair versao atual de CANON_VERSION.md - skip"* — ou seja, esse
hook já vinha pulando por **outro** motivo, antes de chegar no `Join-Path`. É guarda morta
respondendo verde, mesma família do incidente de 2026-07-30, e merece investigação própria.

⚠️ **O BOM caiu três vezes nesta sessão, e a terceira fui eu automatizando.** O harness de mutação
restaurava o arquivo com `ReadAllText` → `WriteAllText`, e esse par **descarta o BOM** (o default
do .NET é UTF-8 sem BOM). Quem escreve script que reescreve `.ps1` do kit tem de passar
`UTF8Encoding($true)` explicitamente — foi exatamente assim que a 6.36.0 perdeu 6 arquivos.

**Teste novo `provider-limites.tests.ps1` (18 casos), guardando a classe e não os quatro casos:**
sampling param proibido por família de modelo; teto mínimo para provider que raciocina; paridade
`.ps1`/`.sh` de teto **e** de timeout; timeout comportando o teto; e o fail-closed do R11 nos dois
runtimes. Mutação confirmada nos três eixos (devolver o `temperature`, baixar o teto, remover o
gate — cada um derruba o teste). Anti-vacuidade em todos os regex.

⚠️ **Armadilha nova, registrada no teste:** não use `<->` em nome de `Describe`/`It`. O Pester
trata `<algo>` como placeholder de dado e expande para `$algo`; `<->` vira `$-` e o bloco inteiro
morre com `CommandNotFoundException` **antes** de rodar qualquer asserção — verde nenhum, vermelho
nenhum, só um bloco que some do relatório. Custou um falso "8 falhas" nesta sessão.

⚠️ **`Edit` em `.ps1` pode comer o BOM.** O `deepseek-review.ps1` perdeu o BOM ao ser editado e
voltou a dar 9 erros de parse no PS 5.1 — a mesma classe da 6.36.2, três semanas depois. Só a
suíte inteira pegou: os testes "do tema" (provider-limites) estavam todos verdes.

**Também nesta versão:** `no-legacy-kit-path.tests.ps1` ganhou `conhecimento/` na allowlist. As 6
ocorrências do nome antigo vivem no verbete `#claudemd-caminho-canon-stale`, cujo **assunto** é
justamente aquele path ter morrido — mesma razão pela qual o changelog já era isento. Esta falha
**precedia** esta sessão (teste e arquivo idênticos em 7e9939c).

Suíte: **321 Pester + 10 pytest, tudo verde.**

**As próprias guardas novas passaram por duas rodadas de aperto, também vindas do R11:** a allowlist
de `conhecimento/` isentava a **pasta** (agora isenta só o arquivo, para que uma referência stale
futura em outro verbete continue pintando vermelho), e a varredura de `Join-Path` não via nem
continuação de linha com backtick nem `-AdditionalChildPath` explícito. A primeira versão do aperto
introduziu **falso positivo em 4 arquivos**, porque `\s` casa através de quebra de linha — separador
entre argumentos agora é espaço horizontal, e comentário é removido antes de casar (senão a guarda
acusa o comentário que **explica** o bug). Mutação confirmada nas três formas: 3 args na mesma
linha, 3 args quebrados com backtick, e `-AdditionalChildPath` explícito.

**Nota de método, porque ela é o ponto desta versão inteira:** os defeitos 6 e 7 foram achados pelo
**próprio R11** revisando o commit que consertava o R11. Um deles (o `Join-Path`) era regressão que
esta mesma versão tinha acabado de introduzir e que nenhum dos 320 testes pegava. O review
cross-provider pagou o próprio custo em um commit — e o único motivo de ele ter podido fazer isso é
que a perna estava viva. Perna muda não reprova nada.

## Changelog v6.36.3 — 2026-08-15

**A perna Cross-Claude respondia e o parser jogava a resposta fora — desde o 6.36.2.** A 6.36.2 subiu
o modelo para `claude-sonnet-5` e ajustou `MaxTokens` para 16000 justamente porque **em Sonnet 5 /
Opus 5 o thinking vem LIGADO por padrão**. Mas a extração da resposta continuou em
`$resp.content[0].text`, e com thinking ligado a API devolve **dois blocos**:

```
content[0].type = "thinking"   (não tem campo .text)
content[1].type = "text"       (a resposta)
```

Índice 0 devolvia `$null`. O provider reportava `status="empty"` com `stop_reason="end_turn"` e
5015 tokens de completion gastos: a chamada era paga, a resposta existia, e o parser descartava.

- `providers/cross-claude.ps1` — `($resp.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text`
- `providers/cross-claude.sh` — mesmo defeito no `jq`, mesma correção: `[.content[] | select(.type=="text") | .text] | first`

🔑 **Por que passou batido:** o teste de fumaça usa prompt trivial (`responda PONG`), e resposta
curta **não dispara bloco de thinking** — o smoke via verde enquanto todo review real voltava vazio.
Perna de conselho tem de ser validada com prompt que force raciocínio; confirmar que a API responde
não é confirmar que o provider entrega.

**A 6.36.2 também subiu o modelo só do lado PowerShell.** O `council-orchestrator.sh` continuou
roteando para `claude-sonnet-4-6` / `claude-opus-4-7`, e foi empurrado assim: quem roda o conselho
por bash consultava outro conselho. Junto vinham `fact-check.sh` (que ainda mandava
`temperature: 0.2` — sampling param que a família Sonnet 5 / Opus 4.7+ **rejeita com 400**, então
trocar só o modelo ali teria quebrado o fact-check em toda chamada) e `smoke-cache-f1.ps1`.
Corrigidos os três, mais dois comentários do `cross-claude.ps1` que ainda citavam a geração 4.

**Teste de paridade `.ps1` ↔ `.sh`** em `cross-claude-mode-load.tests.ps1`: extrai o router por modo
dos dois orquestradores e exige tabelas idênticas, com anti-vacuidade dos dois lados. Mutação
confirmada (trocar um modelo no `.sh` derruba o teste). Ele nasceu **verde e vazio** na primeira
tentativa: existem *dois* blocos `case "$MODE" in` no `.sh` e o regex casou o primeiro, que é o
parser de argumentos — por isso a âncora agora é a própria atribuição de `CROSS_CLAUDE_MODEL`,
exigindo valor `claude-*`. Guarda contra a classe inteira: duas cópias da mesma tabela, escritas em
linguagens diferentes, sem nada comparando as duas.

⚠️ **Limites do provider que ficam conhecidos** (não corrigidos aqui): `-TimeoutSec 60` é hardcoded,
sem parâmetro — diff grande + thinking estoura. E **não reduza `MaxTokens`** para compensar: em
Sonnet 5 o teto cobre pensamento + resposta juntos, então 4000 fez o modelo gastar tudo pensando e
voltar `finish_reason=length` com conteúdo vazio. Encolha o prompt, não o teto.

Medido em 2026-08-15 chamando a API crua para inspecionar a forma da resposta, e confirmado com um
review real de 154 linhas de hook (voltou `status=ok` com 2 achados substantivos, sendo um crítico
de fail-open que a perna DeepSeek não viu).

## Changelog v6.36.2 — 2026-08-15

**O conselho inteiro revisado contra os modelos que realmente existem hoje — e o medidor de gasto
consertado.** Partiu de uma observação do operador no painel da DeepSeek: o gasto tinha subido muito.

- **DeepSeek: `deepseek-v4-pro` → `deepseek-v4-flash`** em todos os caminhos (review R11, council,
  providers, `_registry.json`, `deepseek-impl` do R13). O `-pro` nunca foi escolha de custo: entrou em
  24/07 num conserto de emergência quando a DeepSeek descontinuou o alias `deepseek-chat` e **nenhum
  commit passava**. O verbete escrito no mesmo dia (`#deepseek-chat-modelo-descontinuado`) já
  recomendava `-flash`; o fix aplicou o outro. 3,1× mais barato nos dois lados
  ($0.435/$0.87 → $0.14/$0.28), e o `-pro` é modelo de raciocínio pagando thinking para revisar diff
  de 12 linhas de markdown.
- **Cross-Claude sobe de geração:** Sonnet 4.6 → **Sonnet 5**, Opus 4.7 → **Opus 5**. Haiku 4.5 fica
  no modo `consult` porque não existe Haiku 5. Llama fica: a Groq não tem Llama 4 em produção.
- **`max_tokens` do `cross-claude.ps1`: 4096 → 16000**, e isso não é folga cosmética. Nos modelos 5 o
  thinking vem **ligado por padrão** (em Sonnet 4.6 / Opus 4.7, omitir o campo significava não pensar)
  e o teto limita pensamento **+** resposta juntos. Subir o modelo sem subir o teto reproduziria
  `#resposta-vazia-teto-de-tokens` um degrau acima: HTTP 200, `content` vazio, e o orquestrador
  contando a perna como respondida.
- **Preços corrigidos em dois lugares que mediam errado.** O `_registry.json` e o
  `analyze_council_spend.py` seguiam com o preço do `deepseek-chat` — o commit de emergência trocou o
  nome do modelo e não os custos ao lado. Pior: `claude-opus-4-7` estava tabelado a **$15/$75**, que é
  preço de Opus 4.1 — o relatório inflava o Opus em 3× enquanto subestimava o DeepSeek. Modelos
  aposentados **continuam** na tabela de propósito: log de junho foi cobrado ao preço de junho.
- **Fallback silencioso vira aviso.** `compute_cost` retornava `0.0` para modelo fora da tabela, sem
  dizer nada — foi isso que deixou a troca de 24/07 passar três semanas sem aparecer em relatório
  nenhum. Agora anota em `MODELOS_SEM_PRECO` e o markdown abre uma seção declarando que o total está
  subestimado. Custo desconhecido não é custo zero.
- **O marcador de review passa a gravar `model` e `usage`.** O `latest.jsonl` registrava timestamp,
  diff_lines e findings — nada sobre qual modelo revisou nem quanto custou. Quem grava o veredito
  grava o preço dele.

**Regressão pega pelo próprio review (R11), e ela é a lição da versão.** O `ValidateSet` de
`$CrossClaudeModel` continuava listando só a geração 4. Em PowerShell, `ValidateSet` de **parâmetro
revalida a cada atribuição à variável** — então o router, ao atribuir `claude-sonnet-5` por modo,
derrubaria o council em **toda** invocação, não apenas em quem usasse `-CrossClaudeModel`. Checagem
estrutural nenhuma denuncia isso. Agora há teste em `cross-claude-mode-load.tests.ps1` que extrai o
`ValidateSet` e o `switch` do arquivo e exige que todo modelo produzido esteja permitido, com guarda
anti-vacuidade (regex que parasse de casar deixaria o teste verde sem aferir nada). Mutação
confirmada: tirar um modelo do set derruba o teste.

**BOM restaurado em 6 `.ps1`, e isto NÃO é cosmético.** O script que fez a troca de modelo gravou os
arquivos com `UTF8Encoding($false)` — sem BOM. No PS 5.1 isso faz o arquivo ser lido como ANSI, e o
`deepseek-review.ps1`, que tem prompt acentuado em PT-BR, **parou de parsear** (7 erros). Três dos
seis (`scripts/bump-canon.ps1`, `bump-canon.tests.ps1`, `gate-versao.tests.ps1`) já estavam sem BOM
desde a v6.36.0 — o diff deles nesta versão é de **exatamente uma linha**, a primeira. Ou seja: a
suíte `ps51-compat` já vinha vermelha e passou despercebida porque as versões anteriores rodaram só
os arquivos de teste diretamente ligados à mudança, não a suíte inteira. Um review cross-provider
pediu para reverter o BOM; recusado — é o oposto do que `ps51-compat` exige.

**Mapeamento spec-kit atualizado (v0.16.4, conferido em 14/08).** Os comandos deles agora são
`/speckit.*`, e três não estavam na nossa tabela: `converge`, `taskstoissues` e `checklist`.

310 testes verdes (10 pytest + 300 Pester). Restam 2 vermelhos em `conhecimento/COMO_RESOLVER.md`,
de verbete que outra sessão está escrevendo agora (órfão do índice e sem `tags:`) — fora deste
commit e fora do meu alcance.

## Changelog v6.36.1 — 2026-08-14

**Limitação do gate de versão documentada, em vez de escondida.** O review cross-provider apontou
que `origin/main` é ref de *remote-tracking* **local** e pode estar velha, porque hook de pre-commit
não roda `git fetch` — se outra pessoa publicou uma versão à frente, a checagem 4 compara com a
antiga e libera. A limitação foi **aceita e escrita** (no gate e no verbete), não corrigida: pôr
rede no caminho do commit é lento e quebra offline, e o dano é contido porque o `git push` recusa o
non-fast-forward depois. Gate não substitui estar em dia com o remoto.

**Conhecimento novo (R23), dois verbetes generalizáveis desta sessão:**

- `#concordancia-nao-prova-avanco` — teste que prova que N cópias concordam nunca prova que o valor
  andou. Vale para qualquer dado denormalizado, não só versão: a suíte afere concordância enquanto o
  defeito real é estagnação, e todas as cópias erradas concordam entre si.
- `#gate-le-working-tree-nao-o-indice` — hook de pre-commit que lê o disco afere o que não vai ser
  gravado. Toda leitura que decide veredito sai de `git show :`, `git diff --cached` ou
  `git ls-files`; `cat` e `[ -f ]` só decidem se a checagem **se aplica**.

Este bump é ele próprio a primeira prova de fogo da checagem 4: mexer em `v2/gates/` na versão
6.36.0 já publicada foi barrado, e o caminho de saída foi `scripts/bump-canon.ps1` — exatamente o
desenho pretendido.

## Changelog v6.36.0 — 2026-08-13

**O versionamento deixa de depender de alguém lembrar.** Os 6 testes de
`version-alignment.tests.ps1` provavam que os 4 arquivos de versão **concordam** — nunca que a
versão **andou**. `6.35.0` nos quatro, com um template novo dentro, passa nos seis e mente. O que
faltava era o gatilho, e o gatilho era memória minha.

- **`scripts/bump-canon.ps1 <versao>`** (novo). A versão mora em **7 pontos** espalhados por 4
  arquivos — cabeçalho e changelog do `CANON_VERSION.md`, `version` e `description` do
  `plugin.json`, os mesmos dois do `marketplace.json`, e `.percus-version`. Fazer na mão é o que
  produz drift. Edita por regex no texto cru de propósito: reserializar o JSON reformataria o
  arquivo e produziria diff ilegível. Recusa semver inválido, bump para trás ou repetido, e
  **aborta se já houver drift** entre os 4 arquivos — sem essa última guarda o bump seria parcial e
  silencioso: o script troca a string da versão antiga, então o arquivo já divergente não casa com o
  padrão e sobrevive ao comando que deveria eliminá-lo. A checagem de drift cobre os **6** pontos
  numéricos, inclusive o prefixo `vX.Y.Z |` das descrições — que driftam sozinhas justamente porque
  são reescritas por regex que não olha o valor antigo. Valida tudo **antes** de escrever qualquer
  coisa. 9 testes em `bump-canon.tests.ps1`.
- **Checagem 4 no `v2/gates/percus-gate.sh`** (nova). Barra commit com conteúdo staged em
  `plugin/`, `templates/`, `v2/`, `scripts/` ou `0[1-6]_*.md` enquanto a versão do
  `CANON_VERSION.md` **não avançar** sobre a de `origin/main` — isto é, enquanto você estiver
  acrescentando kit numa versão já publicada. Três detalhes que o review cross-provider extraiu, e
  que sem eles o gate seria teatro:
  - A comparação é contra `origin/main`, não contra "o cabeçalho mudou neste commit", senão o
    segundo commit da mesma versão exigiria bump de novo — e gate que atrapalha ensina a ser
    escapado (ver `#gate-escapado-em-massa-e-regex-errado`).
  - Lê do **índice** (`git show :CANON_VERSION.md`), não do working tree: bumpar e esquecer o
    `git add` deixaria entrar commit com conteúdo novo em versão velha.
  - Exige **avanço**, não igualdade: repo atrasado em relação ao remoto também está commitando em
    versão já publicada.
  - Quem decide se o repo é o canon é o **remoto** (`origin/main` tem `CANON_VERSION.md`), não o
    disco. Ancorar em `[ -f CANON_VERSION.md ]` dava duas portas grátis para desligar o gate —
    `git rm --cached` e `git rm` — e as duas passavam caladas.
  - Comparação semver em `awk`, não `sort -V`: `-V` é GNU-only e o gate roda em qualquer sh.

  Pula sozinha fora do canon e em clone sem `origin/main`. 13 testes em `gate-versao.tests.ps1`.

  **O que NÃO exige bump, de propósito:** `conhecimento/`, `docs/`, `images/`, `Design/`,
  `comandos/` e `checklists/`. A versão significa *"mudou o que um projeto consome como código"* —
  `Design/` é referência visual declarada (não é código), e `comandos/`/`checklists/` são prosa de
  procedimento que muda toda semana. Incluí-los faria cada ajuste de texto exigir bump, e versão
  inflacionada é o caminho conhecido para o gate virar estorvo e o escape virar rotina.
- **As duas peças são uma só.** Gate sem script vira estorvo; script sem gate continua dependendo
  de memória.
- **Correção de rota:** o parágrafo do topo dizia que canon e plugin são sincronizados **via tag**.
  A última tag é `v6.7.2` contra canon `6.35.0` — o mecanismo descrito não existia mais há 28
  versões. Texto corrigido para descrever o que de fato acontece.

**Padrão visual novo: seletor de acessos.** `templates/permissoes-por-perfil/` — editor de
permissões por perfil de usuário, arquitetura de informação da tela "Invite members" da Cloudflare,
direções visuais do PanelKit, implementação em Tailwind + shadcn conforme `02_INFRA`. 35 testes.
`comandos/DESIGN_WORKFLOW.md` passa a rotear tela de permissões para o template antes de cogitar
v0/shadcn.

**PanelKit (`Design/`) versionado e classificado como referência visual**, não fonte de código —
cravado no topo do `Design/readme.md`, na `Design/SKILL.md` (que antes mandava copiar para
produção) e na tabela do `DESIGN_WORKFLOW.md`.

**Comentários de código passam a ser em PT-BR** (`README.md`, `templates/CLAUDE.template.md`,
`templates/AGENTS.template.md`). Identificadores seguem sem regra: o review cross-provider mostrou
que o código real usa nomes em português (`zerarSchema`, `conexao`, `resolverPorPeriodo`), então
cravar "identificadores em inglês" criaria regra que o código já viola em massa.

## Changelog v6.35.0 — 2026-08-07

**R20 ganha um segundo escape hatch: autorização em lote por arquivo.** O hook
`external-action-guard.ps1` já tinha `PERCUS_EXTERNAL_OVERRIDE=1`, mas essa variável não atravessa
a fronteira de processo do `PreToolUse` (achado 2026-07-31) — setar dentro da sessão do Claude não
tem efeito nenhum. Agora existe um segundo mecanismo, em disco: o agente cria
`.percus/acao-externa-autorizada.json` (via `scripts/autorizar-acao-externa.ps1`) **depois** de
confirmação explícita do operador na conversa, com uma janela de 60 minutos calculada em epoch
puro (nunca `DateTime` local, imune a fuso/DST). Os dois mecanismos convivem — qualquer um dos dois
libera a ação externa, nenhum substitui o outro.

Erro na checagem do arquivo (JSON corrompido, campo faltando, arquivo ilegível) é fail-closed:
bloqueia, nunca libera — comportamento diferente do resto do hook, que é fail-open para erro
interno inesperado. Todo uso da autorização em lote é registrado em
`.percus/autorizacoes-usadas.jsonl` via `scripts/registrar-uso-autorizacao.ps1`, pra auditoria
posterior de o que foi liberado, por qual autorização, quando.

Risco estrutural aceito conscientemente pelo operador: o mesmo agente que a R20 existe para conter
é quem cria o arquivo que o hook confia, sem verificação externa de que a confirmação humana
aconteceu de verdade. Ver `docs/superpowers/specs/2026-08-06-r20-autorizacao-lote-design.md` pro
raciocínio completo.

---

## Changelog v6.34.1 — 2026-07-31

**A versão aparece no painel de plugins.** As `description` do `plugin.json` e da entrada no
`marketplace.json` passam a abrir com `v<versão> | …`. Pedido do operador: o painel do VSCode mostra
só a description, então não havia como saber qual versão estava instalada sem abrir arquivo.

Duplicar dado é convite para drift, então a duplicação vem amarrada: `version-alignment.tests.ps1`
passa a exigir que **as duas descriptions comecem com a versão atual**. Bumpar e esquecer de
atualizar vira falha vermelha, não divergência silenciosa — número errado no painel seria pior que
número nenhum, porque número errado parece informação.

O que continua fora da description é o **changelog**, que vive só aqui (R25, single-source). Número
de versão não é changelog.

---

## Changelog v6.34.0 — 2026-07-31

**O enforcement passa a denunciar a própria ausência.** Hook novo `enforcement-health` em
`SessionStart`: no início de cada sessão ele diz, em uma linha, se o enforcement está ligado, quantos
hooks estão registrados, **de onde vem o código** (kit ou cache) e qual a versão. Sempre `exit 0` —
observador, nunca guarda; um health check que tranca a sessão troca um problema por outro pior.

**Ele fala mesmo quando está tudo certo**, e isso não é ruído: health check que só fala em caso de
erro é indistinguível de health check que não rodou, que é exatamente a classe de bug que ele existe
para fechar. O que ele denuncia: código vindo do cache em vez do kit, hook do manifesto ausente do
registro vivo, `command` apontando para arquivo inexistente, versão instalada diferente da do kit, e
`PERCUS_HOOKS_DISABLED` setada como variável de **usuário** — porque aí o escape de emergência virou
estado permanente e desligou três camadas sem ninguém lembrar.

**Por que ele é necessário e não apenas útil.** A 6.33.0 fez o código dos hooks vir do kit, mas
abriu uma ausência silenciosa nova: numa máquina sem `PERCUS_CANON_DIR`, o trampolim cai na cópia
velha do cache **sem dizer nada**. O lugar óbvio para avisar seria o próprio trampolim, e ele não
serve — foi medido que saída de hook que sai 0 é invisível, stderr e stdout. `SessionStart` é o único
canal com visibilidade provada.

Absorve a intenção do órfão `canon-version-check` (versão instalada × versão do kit), que existia em
disco, tinha teste próprio e nunca esteve em registro nenhum.

**Por que houve uma segunda publicação.** O plano 2 previa uma só. Não sobreviveu ao contato, e o
motivo é o próprio argumento da migração pendente: sob o regime do `hooks.json`, **adicionar
qualquer hook custa uma publicação**, porque registro só vale depois de publicado. Quando o registro
migrar para o `settings.json`, hook novo passa a chegar por `git pull` como o código já chega.

---

## Changelog v6.33.0 — 2026-07-31

**O código dos hooks passa a vir do kit. Fix de hook agora chega por `git pull`.**

Os 11 wrappers `.cmd` ganharam um trampolim: quando `PERCUS_CANON_DIR` aponta para uma cópia de
trabalho que tem o hook, é o `.ps1` **do kit** que executa; senão, cai no `.ps1` vizinho, como antes.
Vale para os 11 — as 8 guardas e os 3 observadores —, porque aplicar só nas guardas seria a
meia-correção que já deixou três delas mortas sem ninguém ver.

**Mudança de comportamento a anunciar:** a partir desta versão, editar um `.ps1` em
`plugin/percus-review/hooks/` no kit muda o comportamento na máquina **sem publicar nada**. Isso é o
objetivo — e também significa que uma cópia de trabalho no meio de um rebase, ou numa branch errada,
passa a valer.

**`PERCUS_CANON_DIR` virou uma fronteira de confiança.** Quem controla essa variável passa a
controlar qual código roda como enforcement nos 11 hooks. Diferente de `PERCUS_HOOKS_DISABLED`, que o
canon exige declarar em voz alta, e dos escapes por hook, que são documentados um a um, apontar a
variável para outra árvore troca o código das 8 guardas **em silêncio** — sem log, sem motivo
declarado, sem aparecer no canário. Antes desta versão a superfície equivalente exigia escrita no
diretório do plugin instalado; agora basta a variável de ambiente. É custo aceito, não efeito
colateral esquecido: sem essa resolução não há entrega por `git pull`.

**O que dimensiona esse custo:** quem consegue escrever nas variáveis de usuário da máquina já
consegue setar `PERCUS_HOOKS_DISABLED=1` e desligar as três camadas de enforcement de uma vez — e já
consegue executar código como você por vias que não passam por hook nenhum. A fronteira de confiança
não é nova; ela é a **sessão do operador**, e sempre foi. O que muda é que agora ela também decide
*qual* código de enforcement roda, não só *se* roda. Por isso a mitigação certa não é validar
assinatura do `.ps1` (máquina nova, que precisaria ela própria ser provada): é o health check da
Task 7 **dizer, no início de cada sessão, de onde o código veio** — tornando a troca visível em vez
de tentar torná-la impossível.

**O que o fail-closed cobre, e o que não cobre.** Kit com `.ps1` que não parseia **barra** (exit 2),
e kit com `.ps1` vazio ou só-BOM também **barra** — os dois provados por teste. O segundo caso só
apareceu porque `powershell.exe -File` de um arquivo de 0 bytes sai **0**: script vazio não é
"quebrado" para o parser, é um script válido que não faz nada, e sem checagem a guarda traduziria
isso em "aprovado". Daí o piso de 200 bytes no wrapper (o menor hook real tem 1883 bytes; um teste
amarra essa folga). **Não coberto:** truncamento no meio do arquivo que ainda parseie. O resíduo é
pequeno porque os 11 hooks têm o corpo inteiro dentro de um `try{...}catch{}` — truncar no meio
deixa chave desbalanceada e cai no caminho de parse, que barra. Declarado por ser resíduo conhecido,
não por ser impossível.

Esta é a única publicação do plano 2. Depois dela, o canal de publicação deixa de ser o caminho por
onde conserto de hook viaja.

**Vai junto, e afeta todos os projetos: o conselho parou de chamar perna vazia de "ok".** Os três
providers gravavam `status = "ok"` sempre que a chamada HTTP não lançava exceção, **sem nunca olhar o
conteúdo**. Combinado com `max_tokens = 1024`, isso produziu duas falhas silenciosas na mesma rodada
de pre-mortem: o DeepSeek gastou os 1024 tokens **raciocinando** (em modelos de raciocínio os
`reasoning_tokens` contam dentro de `completion_tokens`) e devolveu string vazia; o Cross-Claude bateu
no mesmo teto e devolveu texto **cortado no meio de uma frase**. As duas foram reportadas como
sucesso, e o log dizia "3 providers chamados" quando havia uma perspectiva só.

Agora há três estados em vez de dois — `ok`, `empty`, `truncated` —, o aviso nomeia a causa em vez do
sintoma, os tetos subiram por natureza do modelo (deepseek 8192, cross-claude 4096, groq-llama 2048),
e o orquestrador emite `respostas_usaveis: N de M`. **Se você usa `/council:*` em qualquer projeto,
esta é a correção que mais te afeta nesta versão** — decisões tomadas com base em "consenso" de
rodadas anteriores podem ter sido consenso de uma perna só. Verbete
`#conselho-perna-vazia-teto-tokens`.

**O que sustenta isso:**

- `hooks/hooks-manifest.json` — fonte única da verdade dos 11 hooks (evento, matcher, forma,
  assinatura de stderr, escape) + o órfão `canon-version-check`, que existe em disco, tem teste
  próprio e nunca esteve em registro nenhum. O `hooks.json` deixou de ser a fonte da verdade dos
  testes porque é ele que a migração do registro esvazia.
- `docs/superpowers/medicoes/2026-07-31-semantica-hooks-harness.md` — 11 itens de semântica do
  harness medidos por observação, com a versão registrada junto, e `scripts/revalidar-medicao.ps1`
  para gritar quando o ambiente mudar e a medição envelhecer.

**Três coisas medidas que contrariam a documentação oficial e valem para quem escreve hook:**

1. O shell que executa o `command` de um hook do `settings.json` nesta máquina é **`/usr/bin/bash`**
   (Git Bash), não PowerShell. `${VAR}` expande por expansão de shell; `$env:VAR` e `%VAR%` não.
2. **Saída de hook que sai 0 é invisível** — stderr e stdout. Só o caminho de bloqueio (`exit 2`) e o
   `SessionStart` têm canal visível. Hook que "avisa" no caminho de sucesso não avisa ninguém.
3. Hook de plugin e hook de `settings.json` **coexistem: os dois rodam**, concorrentes, e qualquer
   `exit 2` bloqueia. Não há precedência.

---

## Changelog v6.32.0 — 2026-07-30

**Três guardas de `PreToolUse` estavam respondendo verde sem rodar.** `external-action-guard` (a que
barra `git push` e `gh pr comment` por R20), `auth-import-pre-commit` e `types-check-pre-commit`. Não
falhavam: **aprovavam**. Duas falhas encaixadas, e é a segunda que transformou a primeira em silêncio.

**1. O gatilho — 34 `.ps1` sem BOM.** O Windows PowerShell 5.1 (`powershell.exe`, que é o runtime real
de todo hook do plugin) lê `.ps1` sem BOM como cp1252. O último byte do em-dash (`E2 80 94`) é `94`,
que em cp1252 é **aspa curva** `”` — e o PowerShell aceita aspa curva como delimitador de string.
Dentro de uma string, ela fecha a string cedo e o arquivo inteiro desanda, com erros de parse
apontando linhas **sem defeito**, às vezes dezenas de linhas depois. 16 arquivos não parseavam; outros
18 parseavam e só imprimiam lixo. A suíte não via nada disso: ela roda em **pwsh 7**, que lê UTF-8 por
default — cega para a classe por construção.

**2. O amplificador — o wrapper `.cmd` traduzia "script morreu" em "aprovado".** A forma era
`-Command "& script; exit $LASTEXITCODE"`. Script que não parseia nunca roda, `$LASTEXITCODE` fica
nulo, e o `exit` sai **0** — que o harness lê como "guarda aprovou".

**O conserto, em camadas.** BOM nos 34 (prepend de bytes; via texto o fim de linha seria reescrito e o
diff viraria arquivo inteiro). Wrappers em duas formas, escolhidas pelo **evento declarado no
`hooks.json`**: os 8 de `PreToolUse` são **fail-closed** (qualquer não-zero vira `exit 2`), e os 3 de
`Stop`/`PreCompact` **repassam** o código — porque nesses eventos `exit 2` barra o encerramento da
sessão e a compactação de contexto, e os três arquivos documentam no próprio cabeçalho que não
bloqueiam por erro. Os dois formatos checam `PERCUS_HOOKS_DISABLED` **na linha 2**, antes de invocar o
PowerShell: sem isso, um `.ps1` corrompido trancaria a máquina, porque o escape de hoje mora *dentro*
do `.ps1` que não roda.

**A regra de encoding mudou: era "100% ASCII", agora é "não-ASCII exige BOM".** Regra sem gate é
sugestão — a de ASCII era violada por 34 arquivos e ninguém sabia. Quem enforça agora é
`tests/ps51-compat.tests.ps1`: um `It` parseia todo `.ps1` sob o `powershell.exe` real; outro barra
qualquer byte `> 0x7F` sem BOM, inclusive nos que parseiam e só imprimem lixo. Verbete
`#ps51-ascii-hooks` atualizado; a memória `feedback_ps51_ascii_hooks` está desatualizada neste ponto.

**Correção de rota na decisão de 01/07 (republish descartado):** ela vale para os **gates**, que
chegam por `instalar-gates.sh` sem depender de publicação. Não vale para os **hooks do plugin** —
`hooks.json` invoca `${CLAUDE_PLUGIN_ROOT}`, que é a pasta **instalada**. Foi por isso que as três
guardas ficaram mortas: o conserto no repo não chega nelas. Ver o bloco no topo deste arquivo.

**Verificado rodando, não por inspeção:** prova de mutação (tirar o BOM de um dos 16 derruba os dois
`It`; de um dos 18, só o de invariante), conserto parcial dos wrappers deixa o invariante vermelho, e
ponta a ponta nas duas formas — guarda com `.ps1` quebrado dá **2** e com `PERCUS_HOOKS_DISABLED=1` dá
**0**; observador com `.ps1` quebrado dá **1** e com `exit 2` próprio dá **2**. Suíte: 203 passando.

**Erro meu que vale registrar:** eu afirmei em duas versões do spec que `-File` fazia a guarda morta
*bloquear*. O contrato documentado é `exit 2` bloqueia e **qualquer outro não-zero é erro visível com
a ferramenta seguindo**. As duas afirmações eram inferência apresentada como medição — exatamente o
defeito que este arco conserta. Spec §3.1 registra a correção.

Spec: `docs/superpowers/specs/2026-07-30-guardas-mortas-powershell-51-design.md` ·
Plano: `docs/superpowers/plans/2026-07-30-guardas-mortas-powershell-51.md`

---

## Changelog v6.31.1 — 2026-07-27

**Dois gates bloqueavam o caminho legítimo — e falso positivo recorrente custa a proteção inteira.**
Os dois falham "pro lado seguro", mas atrito assim é o que ensina a desligar o gate; a partir daí ele
não existe mais. Ambos encontrados rodando o kit sobre ele mesmo no arco da v6.31.0.

**1. `hooks/pre-commit-check.ps1` barrava commit que TINHA review.** Duas causas independentes:
- **Path MSYS.** O agente roda `cd "/d/Claud Automations/repo" && git commit`; o hook extraía esse
  path e entregava pro `git` do **Windows** → `exit 128`, caía no fallback e procurava o review em
  `\d\Claud Automations\repo\.deepseek\reviews`. Agora normaliza `/d/...` e `/cygdrive/d/...` para
  `D:\...` antes de qualquer chamada nativa.
- **`-c` casando como `-C`.** `-match` do PowerShell é case-insensitive, então em
  `git -c commit.gpgsign=false commit` o `-c` casava no padrão de `-C <dir>` e o "repo target" virava
  `commit.gpgsign=false`. Trocado para `-cmatch` **só nesse padrão** (onde o case é semântico).
- O twin `.sh` **não tinha** nenhum dos dois (usa `sed`, ERE case-sensitive, e path MSYS é nativo lá).
- **Verificado RODANDO** — `tests/pre-commit-path-resolution.tests.ps1`, 9 testes: libera path MSYS
  com review fresco; **ainda bloqueia** sem review e com review velho (normalizar não virou bypass);
  libera `git -c ... commit`; `-C <dir>` maiúsculo continua definindo o repo target (inclusive
  bloqueando quando é o target que não tem review, com o cwd revisado).

**2. `v2/gates/percus-gate.sh` acusava 7 violações no canon, 6 falsas.**
- Varria o arquivo **inteiro** atrás de `{#ancora}` e acusava o **bloco-modelo** e a prosa do
  cabeçalho (`{#ancora-kebab}`) como "verbete fora do índice" — em toda rodada, no canon e em todo
  projeto que copia o template. Agora só conta âncora em linha de título (`^## `).
- Exigia **crase** em `` `tags:` ``, mas 18 dos ~100 verbetes escrevem `tags:` sem crase e são
  perfeitamente encontráveis. A crase virou opcional — e isso **revelou** os 2 verbetes que estavam
  mesmo sem tags (`#refresh-wipe-transitorio`, `#auditoria-cross-repo-working-tree`), invisíveis pra
  `consult-knowledge` desde que foram escritos. Ambos ganharam linha `tags:`.
- **Verificado RODANDO**: exit 0 no canon e no V2; e matriz negativa provando que ainda **bloqueia**
  âncora fora do índice e verbete sem `tags:`. Gate que parou de acusar sem provar que ainda pega
  violação real é gate cego.

**3. R23 — 3 verbetes novos em `conhecimento/COMO_RESOLVER.md`:** regra duplicada em `.ps1`+`.sh`
diverge calada · saída de `jq`/`python` no Windows vem com CRLF e o `\r` mata a regex ·
hook em PowerShell bloqueando commit legítimo vindo do git-bash.

**4. ⚠️ Existem DUAS regras de resolução de versão do plugin — hotfix precisa ir nas duas.**
Descoberto porque o fix do hook, sincronizado só em `6.29.0`, continuou sem efeito:
- **`CLAUDE_PLUGIN_ROOT` → `6.28.0`** (o que está em `installed_plugins.json`). É de lá que saem
  **hooks, skills e slash commands** — inclusive o `/percus-review:review` do chat, que roda
  `${CLAUDE_PLUGIN_ROOT}/scripts/review-router.ps1`.
- **`percus-review-auto.*` → maior versão instalada (`6.29.0`)**, por ordenação semver do nome da
  pasta. É o caminho que o agente usa via Bash tool.

Ou seja: o mesmo kit pode rodar **router de uma versão e hook de outra**. Enquanto o republish
estiver descartado, todo hotfix em `scripts/` ou `hooks/` vai nas **duas** pastas (cada uma tem um
`.percus-hotfix.txt` dizendo o que foi copiado à mão e de qual versão-fonte). Sintoma de ter
esquecido: o fix "não pega" e o comportamento antigo continua, sem erro nenhum.

**5. Versões alinhadas: `.percus-version` = `plugin.json` = `marketplace.json` = `CANON_VERSION` =
6.31.1 — agora com teste.** A convenção existia desde a v6.27.0 e já derrapou três vezes por depender
de alguém lembrar: `marketplace.json` travado em 6.16.1, depois um patch atrás em 6.26.0, e agora
**nove versões atrás** (6.29.0 — parado desde aquele release, enquanto o canon andava até 6.30.8).
`.percus-version` estava em 6.30.8. Nada quebra na hora, e é justamente por isso que passa: o preço
aparece num republish futuro, que nasceria com o número errado e criaria um diretório instalado que
mente sobre o próprio conteúdo. `tests/version-alignment.tests.ps1` passa a aferir os 4 arquivos +
a existência da entrada de changelog da versão atual (bump sem changelog = R25 violado).

---

## Changelog v6.31.0 — 2026-07-27

**Router rebaixava o review de arquivo que o projeto declarou sensível (report "Melhoria na VPS").**
Segunda ocorrência da mesma classe de falha do incidente 2026-05-18 — a primeira foi "paga" só
expandindo o array, e a lista global voltou a não cobrir o projeto seguinte.

**O que acontecia.** Commit `da2724f` do "Melhoria na VPS" tocou `execution/n8n_evo_to_gowa.py`
(script com `--apply` que escreve em workflow de n8n **de produção**) e `lib/n8n_client.py`. O
`CLAUDE.md`/`AGENTS.md` daquele repo declaram essas duas pastas como sensíveis — mas o router
**nunca leu config de projeto**: a lista era hardcoded, global, e com taxonomia de produto web
(`auth/`, `payment*/`, `services/webhook/`). Projeto de tooling/infra não tem nenhuma dessas.
Saiu `sensitive=False` → **deepseek simples**. O Cross-Claude, rodado na mão por fora do router,
achou 2 dos 3 bugs da rodada (gate `is None` deixando node vazio migrar sem `--allow-empty`;
`--batch` saindo com código 0 mesmo com falha). Os dois teriam ido pro commit.

**1. Fonte única: `plugin/percus-review/scripts/sensitive-paths.txt`.** A lista existia em **três**
cópias que podiam divergir em silêncio: array no `review-router.ps1`, cadeia `[[ =~ ]]` no
`review-router.sh`, e os testes, que raspavam a regex do fonte `.ps1` com
`[regex]::Matches($c, "'(\([^']+\)[^']*)'")`. Agora os dois routers e os testes leem o mesmo
arquivo. Padrões restritos ao subconjunto portável ERE/.NET (`[0-9]`, não `\d`) — há teste que
barra `\d`/`\w`/`\s`/`(?...)` entrando no baseline.
- Efeito colateral do jeito antigo: `'^\.env'` **nunca foi testado** — não começa com `(`, então
  a regex de raspagem não o capturava. Hoje tem teste.

**2. Extensão por projeto: `.percus-review.json` na raiz do repo revisado.**
`{ "sensitivePatterns": ["(^|[/\\\\])execution[/\\\\].*\\.py$"] }` — somado ao baseline. Cada
projeto declara sua convenção **junto do código, versionada**, em vez de só em prosa no `CLAUDE.md`.
O baseline continua sendo baseline: convenção de um projeto **não** entra nele (foi assim que a
dívida nasceu).

**3. Falha fechada.** Baseline ausente/vazio, JSON inválido, regex que não compila, ou timeout de
match → `sensitive=true` + aviso. Erro de config **nunca** rebaixa o review. Antes, qualquer um
desses cenários viraria "deepseek simples" calado — o mesmo modo de falha do arco inteiro.

**4. Avisos deixam de morrer no `2>/dev/null`.** Os wrappers chamam o router silenciando stderr,
então o aviso agora sai **dentro do JSON** (`warnings[]`) e os dois `percus-review-auto.*` imprimem
cada um com prefixo `WARN (router)`.

**5. Match agora é case-insensitive nos dois motores.** O `.ps1` usava `-match` (CI por default) e o
`.sh` usava `[[ =~ ]]` (CS): `backend/Auth/` escalava no Windows e não escalava no bash. Divergência
real que a lista duplicada escondia.

**Verificado RODANDO** (`tests/router-sensitive-paths.tests.ps1`, 35 testes, Pester 5.7.1 — 35/35):
matriz de 9 cenários nos **dois** routers, incluindo **6 testes de paridade** `.ps1` × `.sh` sobre o
mesmo repo temporário; `execution/*.py` sem config → `deepseek` / com config → `dual`; doc-only com
config → `deepseek` (config não vira `sensitive` global); config quebrada e baseline ausente → `dual`
+ aviso; `.env` e `backend/Auth/` (maiúsculo) → `dual`. Router também exercitado sob Windows
PowerShell 5.1, não só pwsh 7.
- Bug encontrado e corrigido durante a verificação: `jq`/`python` no Windows emitem **CRLF**, e o
  `\r` grudava no fim da regex do projeto (`...$\r` não casa com nada) — o padrão declarado morria
  em silêncio. Só apareceu porque o teste roda o router de verdade, não a lógica de matching.

**6. `percus-review-auto.*` loga `pasta=X plugin.json=Y`.** Logava só o nome da pasta, e sessão de
adoção já reportou "drift" que não existe (pasta `6.29.0` contendo `plugin.json` 6.30.x é o esperado
— republish descartado em 01/07/2026, ver ressalva no topo deste arquivo).

> **Nota de congelamento (V1 durante o piloto V2).** `MIGRACAO.md` congela o V1 exceto correção de
> bug crítico. Esta entrada foi autorizada pelo operador como bug crítico: o router rebaixando
> review de código que escreve em produção já deixou 2 bugs passarem. Os arquivos do router no
> **cache instalado** (`plugins/cache/.../6.29.0/scripts/`) foram atualizados junto — sem isso o fix
> ficaria inerte, porque os wrappers executam o cache, não o repo.

---

## Changelog v6.30.8 — 2026-07-21

**Higiene de doc a partir dos reports de adoção (auth-service + WhatsApp-API).** Sem mudança de código.

- **`REORGANIZAR_PROJETO.md` (Passo B3): PLANO.md não tem teto de gate — dito explicitamente.** O
  commit-referência (tiatendo `70c9347`) compactou PLANO, mas o texto do B3 só falava de HANDOFF —
  divergência que confundiu a sessão de adoção do auth-service. Agora o B3 diz: PLANO é mapa de
  features (sem teto), mas frente ENCERRADA inchando `docs/PLANO.md` é custo de boot (é boot-read);
  mover pra `docs/historico/` é higiene opcional. `referencia-operacional.md` só com conteúdo real,
  não por paridade. Também anota que o gate afere HANDOFF/CONTEXT na raiz E em `docs/` (v6.30.7).
- **`CANON_VERSION.md`: ressalva de que o plugin INSTALADO fica legitimamente atrás do source.** A
  sessão do WhatsApp-API flaggou "plugin uma versão atrás" — mas o header afirmava tag-sync sem a
  ressalva do republish descartado (01/07). Agora explicita: cache atrás do canon é ESPERADO, gates
  chegam via `instalar-gates.sh` self-contained, não por republish. Mata o re-flag na próxima adoção.

---

## Changelog v6.30.7 — 2026-07-21

**2 achados do report de adoção do Paid Midia Automation — ambos verificados RODANDO.**

**1. Gate cego a `docs/HANDOFF.md` (o teto do HANDOFF não disparava neste projeto).** `percus-gate.sh`
fazia `checar_tamanho "HANDOFF.md"` — glob só de raiz. Projeto que guarda o HANDOFF em `docs/`
(desvio de layout, mas real) passava calado: `docs/HANDOFF.md` de 245 linhas dava `exit 0`. É o
mesmo modo de falha "passa calada" do arco inteiro, e a sessão provou rodando (245→exit0 na raiz-glob,
mesmo conteúdo em `HANDOFF.md`→exit1). Havia sido levantado antes e **caiu no vão — nunca registrado
no canon**. Fix: os globs de `HANDOFF.md` e `CONTEXT.md` cobrem também `docs/`. Gate que só dispara no
caminho abençoado é o próprio "depende de alguém lembrar" que a Constituição §6 proíbe.
- **Verificado RODANDO** (4 cenários): `docs/HANDOFF.md` 245→exit1 · 80→exit0 · `HANDOFF.md` raiz
  200→exit1 (sem regressão) · `docs/CONTEXT.md` 160→exit1.

**2. Compactação que relê o HANDOFF (e não o PLANO) propaga estado fantasma.** Um `[4-C]` fantasma
sobreviveu 7 semanas no HANDOFF do Paid Midia: a linha errada nasceu na véspera de um fix, sobreviveu
à compactação do canon V2 e foi promovida de um doc de 660 linhas a fato num de 34 — porque a
compactação releu o próprio HANDOFF em vez de reconciliar contra o PLANO, que carregava a evidência
do smoke. Fix: `loops/checkpoint.md` ganha a regra — ao reescrever, cada "Em obra" é conferido no
PLANO; se o PLANO marca `[5-T]` com evidência e o HANDOFF diz "em obra", **o PLANO vence**.

---

## Changelog v6.30.6 — 2026-07-21

**`instalar-gates.sh` respeita `core.hooksPath` (3º achado de sessão fria).** Repo com
`core.hooksPath` (husky `.husky`, `.githooks`) roda os hooks de OUTRO diretório — instalar em
`.git/hooks/` plantava o gate onde o git **não olha** → gate ausente, e o auto-cura nunca
alcançava. Fix: o instalador resolve o dir real (absoluto direto; relativo ancorado na raiz do
repo; backslash do Windows → forward pro git-bash). O fallback `.git/percus-v2-dir` independe do
hooksPath (git-dir é sempre `.git`). Re-rodei nos 5 repos com `core.hooksPath` e verifiquei
**RODANDO o hook ativo** env-less: Familia-Milionaria (`.githooks`) + 4 que apontam pro próprio
`.git/hooks`. Nenhum estava quebrado (Familia já curada à mão; os 4 coincidiam com `.git/hooks`),
mas agora é correto por construção. 6º furo do dia achado por revisão externa, todos consertados.

---

## Changelog v6.30.5 — 2026-07-21

**`instalar-gates.sh` agora é IDEMPOTENTE e AUTO-CURA — 2º achado de sessão fria.** O fix da
v6.30.3 adicionou o fallback `.git/percus-v2-dir` **só pra instalações novas**. Hooks já
instalados (consertados à mão pelas sessões) tinham o bloco ANTIGO, que só lê a env var — e
`PERCUS_CANON_V2_DIR` (setado via `setx`) **não aparece em toda sessão de git-bash**. Resultado:
hook **fail-closed TRAVADO** (bloqueava QUALQUER commit no check de env var, sem nunca chegar ao
teste de tamanho). "Emperrado", não "vivo".

- Falha minha de verificação, dita com todas as letras: declarei os hooks "VIVO" checando a
  ESTRUTURA (gate alcançável), **nunca rodei o hook num shell sem a env var**. A sessão fria
  rodou de verdade e travou. "O script funciona" ≠ "o hook roda no commit sem a env var".
- Fix: o instalador **remove o bloco `percus-v2-gate` existente** (marcador a marcador) antes de
  replantar o atual. Re-rodar cura instalação antiga — vira o bloco com fallback.
- **Verificado RODANDO** (não olhando): hook antigo + env var unset → travava; após reinstalar,
  barra HANDOFF de 200 linhas **por tamanho** e passa com 80, **tudo com a env var unset**.
  tiatendo e Plexco curados e testados env-less.
- Remediação nos projetos passa a ser trivial: **só re-rodar o instalador** (não mais remover
  bloco à mão).

---

## Changelog v6.30.4 — 2026-07-21

**Execução de plano é subagent-driven por DEFAULT — "subagent ou inline?" vira pergunta boba.**
Pedido do operador: as sessões estavam perguntando como executar um plano (subagent vs inline);
o default sempre foi subagent-driven (ganho de produtividade + corta contexto principal). Vira
regra pra não perguntar mais.

- `v2/CONSTITUICAO.md` §5 (paralelismo) e `01_REGRAS §R9` ganham: plano/frente com 2+ tasks
  independentes → um subagente por task, revisa entre tasks, **sem perguntar**. Inline só pra
  tarefa única trivial (subagente seria puro custo). Mesma família da trava-boba que R5 combate.

---

## Changelog v6.30.3 — 2026-07-21

**`instalar-gates.sh`: gate era instalado MORTO — achado por sessão fria de adoção B3.**
Duas falhas de composição que meus testes de ontem não pegaram (rodei `percus-gate.sh`
direto, nunca *através* do hook num commit real — "o script funciona" ≠ "o gate roda"):

- **Dead code:** o `cat >>` anexava o gate DEPOIS do hook R11 do percus-review, que termina
  em `exit 0` no sucesso → o gate nunca executava. Instalava e ficava inerte, sem avisar.
  Fix: o instalador **remove o `exit 0` sentinela** (última linha não-vazia) antes de anexar,
  tornando o gate alcançável.
- **Fail-closed travava commit legítimo:** o gate dependia só da env var `PERCUS_CANON_V2_DIR`,
  que **não propaga pra shells já abertos**. Fix: o instalador grava o caminho em
  `.git/percus-v2-dir` (não versionado) e o hook lê a **env var OU o arquivo**.

Provado: hook com `exit 0` sentinela → após instalar, barra HANDOFF de 200 linhas (exit 1)
**mesmo sem a env var**, e passa com 80. Os 2 pilotos já estavam VIVO (sessões consertaram
os próprios hooks); esta correção evita que as próximas adoções B3 instalem gate morto.
Mesmo padrão do dia: sessão fria acha o furo → conserta no canon → então espalha.

---

## Changelog v6.30.2 — 2026-07-20

**Regra de parada no `conselho.md` (achado da sessão fria do piloto-2).** O critério de
promoção do V2 (`v2/MIGRACAO.md`) exigia uma sessão fria — outro agente, sem o autor dos
loops — usando o canon. Aconteceu: a sessão do Plexco Tasks rodou o ciclo V2 completo na
feature A1 (grilling→spec→conselho→tdd→review→deploy), entregou em prod e **criticou o canon**.
Veredito: **net-positivo** ("mais rápido seria pior" — sem o canon teria errado o "% vs N/M"
e shipado o título espremido). Critério de promoção fechado 4/4.

- **Defeito que a sessão fria achou:** `conselho.md` não tinha **regra de parada**. Numa barra
  de progresso o conselho rodou **4 rounds** — o real saiu no round 1, os 2-4 foram defesa
  contra findings alucinados. Sem teto, num pino em que um provedor alucina, rodaria sem fim.
- **Fix (entregue pronto pela própria sessão fria):** teto de **2 rounds**; só HIGH/CRITICAL
  confirmado por fact-check **bloqueia**; o resto vira **risco documentado** na spec/PLANO, não
  3º round. Rodar de novo sem pergunta nova = anti-padrão do escape reincidente (`drift.md`).
- **V2 PROMOVIDO** (de "com ressalva" → promovido): boot −83%/−75%, retrabalho baseline
  18,2%/15,1%, conselho 3/3, sessão fria net-positiva. Liberado pra propagação (Delta B3).
- Aberto (não bloqueia, tem workaround): bug no `council-orchestrator.ps1` (perna Cross-Claude
  recebe blocos `file:` vazios → bloqueio falso HIGH) — spawnado como tarefa própria.

---

## Changelog v6.30.1 — 2026-07-20

**Hook R11 O(N)→O(1): `latest.jsonl` fixo + escrita atômica + auto-poda.** O hook lia o review
mais recente com `stat` em TODOS os `.deepseek/reviews/*.jsonl`; o wrapper gravava 1 arquivo
por review (TTL 5min). O dir só crescia → tiatendo 2026 arquivos → commit pendurava **148s** e
travava o projeto. 11 projetos afetados (Paid Midia 1399, Plexco Tasks 1123, Plexco Coach 844).

- Wrapper (`deepseek-review.ps1`/`.sh`) grava sempre `latest.jsonl` (escrita atômica tmp+rename)
  e **auto-poda** os irmãos — pilhas legadas drenam sozinhas no próximo review, sem tocar nos
  hooks instalados. Leitores (template + `pre-commit-check.*`) leem path fixo O(1).
- Medido: **148s → 1,1s** (127×). Fonte + 2 caches (6.28.0/6.29.0) alinhadas; 11 pastas limpas.
- Verbete R23 `#estado-append-only-trava-hook`. Sem republish (chega via `git pull`).

---

## Changelog v6.30.0 — 2026-07-20

**Canon V2 dobrado pra dentro do kit (`v2/`) + loop TDD + roteador de loops no template.**
O greenfield `_Novo_Projeto_V2` (experimento aprovado no piloto-1) muda de casa pra pegar
carona na entrega que já existe (`git pull` nas 10 máquinas). A pasta avulsa vira arquivo.

- **`v2/`** entra no kit: `CONSTITUICAO.md` (74 linhas, teto 80) + **8 loops** ≤60
  (`grilling`, `spec`, `conselho`, `tdd`, `review`, `deploy`, `checkpoint`, `drift`) +
  4 formatos de artefato + gates mecânicos com instalador standalone (zero dependência de
  republish do plugin).
- **Loop `tdd` é novo** (conselho 3/3): teste nasce antes do código; pular é legítimo **se
  registrado** no PLANO (`tdd: pulado — motivo`) — o `drift` conta os pulos.
- **Roteador de loops** em `templates/CLAUDE.template.md`: o CLAUDE.md do projeto passa a
  rotear situação → loop, resolvendo o disparo (skill de plugin auto-triggava; doc não —
  o roteador devolve isso sem republish).
- **Piloto-1 (tiatendo) FECHADO** — commit `70c9347` lá: boot 7.612→1.297 (−83%), HANDOFF
  6.185→56, CONTEXT.md + 10 ADRs minerados, gate V2 em produção no pre-commit (híbrido,
  R11 preservado). Meta "≤400" substituída por critério por-projeto (HANDOFF no teto +
  PLANO só vivo). Piloto-2 planejado: Plexco Tasks (best-case).
- Adoção nos projetos: caixa Delta `comandos/REORGANIZAR_PROJETO.md` **Passo B3**.
- Versões: `.percus-version` = `plugin.json` = `CANON_VERSION` = **6.30.0** (sem republish
  do plugin — mudança é toda doc/gates, chega via `git pull`).

---

## Changelog v6.29.0 — 2026-07-14

**Autonomia — "menos confirmação boba, IA resolve o máximo" (pedido do operador).** Diretivas de comportamento
elevadas de opt-in/permissivo pra imperativo, **todas doc** (chegam aos projetos via `git pull`):

- **R11 auto-review OBRIGATÓRIO** (não mais só "autorizado"): o agente sempre dispara o review sozinho antes de
  commit. Pedir "`/percus-review:review`" ao operador = ERRO (anti-padrão explícito em `01_REGRAS §295`).
- **Conselho automático** (`06_CONSELHO` Modo 3/5): ao finalizar spec → `spec-analyze` sozinho; ao finalizar
  plano → `council-pre-mortem` sozinho. Sempre, sem perguntar. Hook `pre-plan-exit` (>500 linhas) vira backstop.
- **Paralelismo = DEFAULT ativo** (`R9`): subagents / frentes disjuntas / tool-calls concorrentes buscados
  ativamente, não só "quando cabe". Deixar de paralelizar quando cabia = anti-padrão.
- **R5 reescrito:** confirmação é EXCEÇÃO. Resolve sozinho review/testes/build/checkpoint e limpa **LIXO
  AUTO-CRIADO** sem perguntar. **Autorização durável de deploy/mutação-de-prod** (env-add, restart, redeploy,
  rollback, migration com `downgrade` testado) → executa direto. Confirma só destruição irreversível de dados
  (`DELETE`/`DROP` em prod, force-push que apaga história), e como **pergunta binária — nunca menu (a)/(b)/(c)**.
- `templates/CLAUDE.template.md` ganha seção "Autonomia" espelhando isso pros projetos; caixa-de-delta em
  `comandos/REORGANIZAR_PROJETO.md` (Passo B2) instrui a adoção.
- **Fronteira honesta:** destruição irreversível de dados e ações proibidas do harness (credencial em tela de
  login) seguem com gate — limite do harness, não do canon.
- Versões alinhadas: `.percus-version` = `plugin.json` = `marketplace.json` = `CANON_VERSION` = **6.29.0**.

---

## Changelog v6.28.0 — 2026-07-01

**Fechar soaks órfãos + parity `.sh` (gap aceito + guard fail-closed).** Follow-up do Bloco 4 da v6.27.0;
decisões via conselho (`.deepseek/council-log`) + escolha do operador.

- **2 soaks FECHADOS formalmente** (conselho 2-1 — DeepSeek+Cross-Claude vs Llama). Ambos venceram no
  papel mas **nunca coletaram dado** (instrumentação zerada: `factcheck-triage.jsonl` nunca criado, shadow
  nunca ligou; `crud-warn.log` inexistente): (1) **enforcement de tracking** (v6.12.0) fica **warn-only
  permanente** — sem promoção warn→block; (2) **factcheck-triage** (v6.14.0) fica **shadow-off, sem gate**.
  Motivo: operador solo, 1 runtime, plugin nem republicado — montar coleta não se paga, e amostra minúscula
  daria falsa confiança (block prematuro trava o próprio push; gate errado pula o Sonnet e deixa passar
  factcheck ruim). Deixam de ser pendência. Reabrir só sob pedido explícito (setup: shadow em 2 projetos,
  janela por ≥30 eventos).
- **Parity `.sh` — gap aceito + exceção de segurança** (conselho 3/3). Nova nota "Runtime suportado &
  paridade `.sh`" no `01_REGRAS_INEGOCIAVEIS.md` (R20): **Windows/PowerShell = runtime suportado; `.sh` =
  best-effort**, não portar até surgir consumidor Unix (porta divergente sem teste = falsa paridade). Gaps
  aceitos: `fact-check-triage.sh` (sem shadow/gate), `council-tiebreaker` (lib `.ps1` vs inline no `.sh`).
- **`external-action-guard.sh` criado — stub FAIL-CLOSED.** A ausência do `.sh` não era gap de paridade,
  era **bypass silencioso** do gate R20 no Unix (push/PR-comment passavam sem enforcement). O stub bloqueia
  ação externa pública (git push / gh pr|issue / slack-cli / mailto:) sem `PERCUS_EXTERNAL_OVERRIDE=1`,
  com fallback que **falha fechado mesmo sem `python3`** (casa os padrões no stdin cru). Não reimplementa o
  check de `premise_validity` do `.ps1` (esse segue Windows-completo). Validado: bloqueia/permite/override ok.
- Versões alinhadas: `.percus-version` = `plugin.json` = `marketplace.json` = `CANON_VERSION` = **6.28.0**.
  Segue **repo-only** até o republish (instalado 6.16.1).

---

## Changelog v6.27.0 — 2026-07-01

**Aposentar cascata + higiene R25 (R-count) + otimização de deploy aditiva.** Release vetada pelo
conselho 3/3 (pre-mortem + consult) — log `.deepseek/council-log/20260701-082640-pre-mortem.jsonl`.

- **Cascata v6.13.0-alpha formalmente APOSENTADA/absorvida.** Reconciliação: o eixo *retomada barata* já é
  checkpoint/RESUME_PROMPT/PreCompact (v6.19); *decompor-em-frentes* já é nativo do `PLANO.template`;
  *paralelismo real* é o `COMANDO_FRENTES_PARALELAS` (v6.20). A versão `6.13.0` segue **pulada de
  propósito**; não havia doc de design a deletar (só existia como versão reservada). Registrado como guia
  de decisão em `conhecimento/COMO_FAZER.md#decompor-frentes` — não reintroduzir mecanismo cascata
  separado (seria duplicar = viola R25).
- **Higiene R25 — R-count vira ponteiro sem número** (mata a classe de drift na raiz, veredito 3/3 do
  conselho). Refs de **total** de regras deixaram de cravar "R1-Rn" (que defasava a cada regra nova):
  `README.md` (×2), `templates/project-persona.template.md`, `comandos/COMANDO_PROJETO_NOVO.md`
  (estava em **R1-R19**), `comandos/REORGANIZAR_PROJETO.md` (estava em **R1-R24**). Os **subsets**
  intencionais dos prompts de review/consult/analyze (R1-R13/R19/R23 — o revisor foca um subconjunto)
  foram **preservados** de propósito.
- **`plugin.json` description → ponteiro puro** (parou de cravar "Versao atual: 6.25.0" + destaques —
  violava o próprio R25). `marketplace.json` 6.26.0 → 6.27.0 (estava um patch atrás). Versões alinhadas:
  `.percus-version` = `plugin.json` = `marketplace.json` = `CANON_VERSION` = **6.27.0**.
- **Otimização de deploy (ADITIVA / opt-in)** — recipe comprovado em produção (build Docker Next.js frio
  ~7-8min → ~1-3min): fontes self-hosted (`next/font/local`) + cache incremental BuildKit
  (`--mount=type=cache`). Entrou como **melhoria opt-in** ("pilotar antes de adotar"), **sem mudar a base**
  (decisão explícita do operador + conselho 3/3): nova entrada `conhecimento/COMO_FAZER.md#deploy-build-cache`
  + 1 anti-padrão em `comandos/DEPLOY.md`. **Não** se criou exemplo Next dedicado nem se tocou o Dockerfile
  do auth-service (`02_INFRA`) ou o scaffolding de projeto — o conselho vetou fabricar base não-validada.
- **Nota honesta (repo-only):** o fix de versão/description corrige o **repo**, mas o plugin **instalado**
  segue **6.16.1**; o tooling novo só chega aos projetos após o **republish** (operador-gated). O drift
  plugin↔repo persiste até lá.

---

## Changelog v6.26.1 — 2026-06-27

**Varredura de refs mortas (#4) + housekeeping de branches (#6).**

- **README destralado:** linha de estado listava versão fixa (v6.16.1) + changelog inteiro duplicado
  (violação R25) → agora aponta pro `CANON_VERSION` (single-source). `R1-R22` → `R1-R25`.
- **Ref morta removida:** `diagnostico-disco-c-2026-05-15.md` (não existe) em `AMBIENTE_LOCAL_OPERADOR`.
  Verificado: `OWNERSHIP.md` **existe** (refs preservadas).
- **Branches locais merged apagadas:** `fase5-superpowers-adoption`, `feat/v6.12.0-enforcement`,
  `feat/v6.14.0-groq` (todas em `main`). Mantida `canon/auth-service-fase1-3-aprendizados`.
- Classes de rot já zeradas em releases anteriores: `_AUDIT_*` (v6.23.2), paths `6.0.0` (v6.23.1),
  planos transient `.claude-home/plans` (v6.24.0).

---

## Changelog v6.26.0 — 2026-06-27

**Legal em 2 páginas + e-mail por domínio · marketplace.json destravado · Codex 100% removido.**

- **Legal (passo 2.6 do `COMANDO_PROJETO_NOVO`):** projeto novo agora gera **DUAS páginas separadas** —
  `docs/legal/termos-de-uso.md` + `docs/legal/politica-de-privacidade.md` (nomes padrão), não mais o
  combinado `TERMS_PRIVACY.md`. **Regra nova:** o e-mail de contato segue o **domínio do projeto**
  (`legal@huboperacional.com.br` → `legal@<domínio-do-projeto>`).
- **`marketplace.json`:** estava travado em **6.16.1** (versão + description stale — parte do porquê o
  plugin instalado não atualiza) → **6.26.0** + description concisa apontando pro `CANON_VERSION` (R25).
- **Codex 100% removido** (operador: "não usamos e não pretendemos voltar"): deletado
  `comandos/SETUP_CODEX_REVIEWER.md`; removido **Caminho B** (migração Codex) do `UPGRADE_PARA_FASE4`;
  removidos **Passo 1.5** + detecção/resíduo Codex do `UPGRADE_PROJETO_FASE2` e do `HEALTHCHECK`; `.codex/`
  fora dos `.gitignore`; ~20 docs/templates/checklists neutralizados ("Codex revisa" → "revisor
  cross-provider"). Permanece **só** menção histórica neste changelog.
- `plugin.json` description encolhida (parou de duplicar o changelog — R25).

---

## Changelog v6.25.1 — 2026-06-27

**Dogfooding R23: registra o incidente do sed/JSON na base de conhecimento.**

- `conhecimento/COMO_RESOLVER.md` — nova entrada "Editar JSON via sed/CLI quebra a string com aspas"
  (incidente v6.25.0: `sed` inseriu aspas duplas no valor da `description` do `plugin.json` → JSON
  inválido; pego na validação `ConvertFrom-Json` antes do commit). Solução: aspas simples/nenhuma em
  valor JSON, ou Write do arquivo inteiro; sempre validar antes de commitar.

---

## Changelog v6.25.0 — 2026-06-27

**D2 resolvido: refrescar framing da chain (NÃO arquivar). Re-consulta ao conselho 3/3 flipou B→C.**

A chain de fase foi levada de volta ao conselho **com o mapa de refs completo** (~13 refs ativas em 9 arquivos + procedimentos válidos referenciados por regras ativas). Os 3 membros (DeepSeek, Llama, Cross-Claude) **FLIPARAM de B (arquivar) → C (refrescar)**: arquivar conteúdo válido por causa do nome violaria o single-source (tira o procedimento de onde as regras ativas o esperam). 1ª rodada (2 membros, sem mapa) tinha votado B.

- **Pontos de entrada "atualizar projeto" repontados pro umbrella `REORGANIZAR_PROJETO`:** `README`, `CLAUDE.template` (×2), `SETUP_NOVA_MAQUINA` (×2), `COMANDO_PROJETO_NOVO`, `CHECKLIST_INICIO_SESSAO`. Agora há **uma entrada única de verdade** (antes mandavam direto pra FASE6/FASE7/PROJETO_FASE2).
- **`HEALTHCHECK_FASE2` reenquadrado:** é auditoria de adoção de tooling (review+DeepSeek), função distinta da chain; nome "Fase 4" é histórico. Para *atualizar*, umbrella.
- **Refs a PROCEDIMENTOS específicos preservadas no lugar** (R7.5→FASE7 §2 migração de audience; `UPGRADE_ADICIONAR_SKILLS`→FASE7 §8) — single-source: o procedimento fica onde a regra o espera.
- Chain mantida (pointer headers v6.23 + framing corrigido); **R25** previne drift de nome futuro.

- **`plugin.json` description encolhida** — duplicava o changelog inteiro do `CANON_VERSION` (violação da própria R25 recém-criada). Agora: 1 linha da versão atual + ponteiro pro single-source.

Encerra a frente de consolidação da família "atualizar projeto" (umbrella REORGANIZAR_PROJETO + chain como sub-rotas específicas).

---

## Changelog v6.24.0 — 2026-06-27

**Single-source-of-truth (R25) + fix do model-router fantasma. Decidido com o conselho (2/2).**

Após auditoria das sub-rotas, o operador exigiu o princípio single-source. Conselho consultado (DeepSeek+Llama, 2/2): D1=remover refs transient + regra; D2=arquivar a chain de fase. **D1 e o fix do model-router entregues aqui; D2 (arquivar) PAUSADO** — o mapa de refs inbound revelou que a chain contém procedimentos VÁLIDOS (ex.: migração de audience em FASE7 referenciada pela R7.5 ativa) só com framing stale; arquivar orfanaria refs ativas. Levado de volta ao operador.

**D1 — Single-source (R25):**
- **Nova regra `R25`** em `01_REGRAS`: info tem um dono canônico; reforço = ponteiro pro doc vigente, nunca cópia; canon nunca cita arquivo efêmero/externo (`.claude-home/plans/*`). Gate: grep retorna 0.
- **9 refs a planos transient** (`.claude-home/plans/*`) removidas de 6 docs (`01_REGRAS`, `PADRAO_AUTH_SERVICE`, `AMBIENTE_LOCAL`, `CHECKLIST_AUTH_NOVO_PROJETO`, `MIGRATION_KIT_AUTH.template`, `MIGRAR_AUTH`). Refs cross-repo a repos reais preservadas.

**Q1 — model-router fantasma:**
- `04_MODEL_ROUTING.md` §"Wrapper unificado" reescrita: não existe `model-router.ps1`; o roteamento real é em 2 camadas (`review-router` pra review, `council-orchestrator` pro conselho) + matriz de decisão aplicada pelo agente (R13). Tabela task→modelo vira guia, não comando.

---

## Changelog v6.23.2 — 2026-06-26

**Completa o fix de refs `_AUDIT` (a v6.23.1 foi parcial — varredura canon-wide pegou o resto).**

A v6.23.1 corrigiu só as refs que eu estava olhando; a varredura ampla achou o mesmo `_AUDIT_2026-05-15.md`
(deletado na v6.11) ainda referenciado em mais 3 lugares vivos:
- `06_CONSELHO_PERCUS.md` (refs: audit + plano transient) — removidos.
- `01_REGRAS_INEGOCIAVEIS.md` (linha "Auditoria completa em…") — removida, mantém ref do conselho.
- `plugin/percus-review/commands/drift-detect.md` (refs: "Auditoria similar") — removida.

Agora `_AUDIT_2026-*` só aparece no changelog histórico (correto). **Pendente de decisão** (não mecânico):
(1) `04_MODEL_ROUTING` cita `model-router.ps1` inexistente; (2) ~10 refs a planos transient em
`.claude-home/plans/` espalhadas pelo canon (smell arquitetural — canon citando arquivo externo efêmero).

---

## Changelog v6.23.1 — 2026-06-26

**Fix de rot nas sub-rotas + docs raiz (refs mortas + bug estrutural). Auditoria a pedido do operador.**

Ao reconferir o conteúdo das sub-rotas (não só os headers), achei rot acumulada:
- `UPGRADE_PARA_FASE6.md`: ref morta `_AUDIT_2026-05-15.md` (2×, arquivo deletado na v6.11) → repointada/removida; **"Passo 8" duplicado** → 2º vira Passo 9; ref a plano transient morto removida.
- `SCOPE_COUNCIL.md`: ref morta `_AUDIT_2026-05-17_eixo-f...` removida (inline).
- `SETUP_CATALOG.md`: path do cache do plugin fixado em `6.0.0` → fonte canônica; ref a plano transient removida.
- `06_CONSELHO_PERCUS.md` + `05_FEATURE_TRACKING.md`: paths `…/percus-review/6.0.0/…` fixados → `${PERCUS_CANON_DIR}/plugin/…` (fonte canônica, version-agnostic).

**NÃO corrigido (precisa de decisão, não é mecânico):** `04_MODEL_ROUTING.md` §"Wrapper unificado" descreve `model-router.ps1` que **não existe** no canon (só `review-router.ps1`, que faz outra coisa) — doc-vs-realidade drift; repointar enganaria. Registrado pra decisão.

---

## Changelog v6.23.0 — 2026-06-26

**Consolidação da família "atualizar projeto existente" (corrige sprawl de comandos). Canon-only.**

A pasta `comandos/` tinha 8 docs sobrepostos pra "atualizar projeto existente" (REORGANIZAR stale na
Fase 2 + chain de fase FASE4/6/7 parada em v6.8 + PROJETO_FASE2 + minhas adições v6.18/v6.22). Sem ponto
de entrada único. Auto-crítica: a v6.22 (`UPGRADE_CANON_ATUAL`) foi mais um arquivo paralelo numa família
já inchada, em vez de consolidar.

- **`comandos/REORGANIZAR_PROJETO.md` reescrito como UMBRELLA único** (version-agnostic): diagnóstico de
  versão → tracking files (referencia `templates/`, não inline — tira bloat) → adoção das diretivas
  vigentes (R10-R24, gate [S], R23, R24, checkpoint, auth #rt=) → **roteia** pros setups focados
  (`SETUP_*`/`MIGRAR_AUTH`/`UPGRADE_ADICIONAR_SKILLS`) sem duplicá-los. Atualizado de 2026-04-25 (stale
  Fase 2) pra corrente.
- **`comandos/UPGRADE_CANON_ATUAL.md` DELETADO** — conteúdo (adoção de diretivas + bump + pré-req de
  máquina) fundido no umbrella. (Existia só desde v6.22; ref ativa única era no `00_LEIA_PRIMEIRO`, corrigida.)
- **Rotas de fase marcadas como sub-rotas** (header de ponteiro pro umbrella, não-destrutivo):
  `UPGRADE_PARA_FASE4/6/7`, `UPGRADE_PROJETO_FASE2`. Refs ativas (HEALTHCHECK, CHECKLIST_INICIO,
  CLAUDE.template) **preservadas** — continuam válidas. Corrigido o título enganoso de FASE6 ("versão
  canônica atual" — não é mais).
- **`00_LEIA_PRIMEIRO.md`** — roteamento consolidado: 1 linha pro umbrella; removida a do arquivo deletado.

Sem cirurgia de refs arriscada: o umbrella reforça refs que já apontavam pra REORGANIZAR
(`00_LEIA`, `README`, `CHECKLIST_INICIO_SESSAO`); as rotas de fase seguem funcionando.

---

## Changelog v6.22.0 — 2026-06-25

**Caminho de adoção: como projetos existentes recebem as diretivas novas. Canon-only.**

Faltava o "cole no chat" que sincroniza um projeto existente com a versão canônica atual (as diretivas
v6.17-v6.21 não tinham um comando consolidado de adoção — só `UPGRADE_ADICIONAR_SKILLS` cobria a v6.18).

- `comandos/UPGRADE_CANON_ATUAL.md` — **version-agnostic**: o operador cola o bloco no chat de cada
  projeto; ele lê `.percus-version` vs `CANON_VERSION.md`, adota as diretivas vigentes (gate `[S]`,
  R23, R24, checkpoint, skills locais, `#rt=` auth, frentes paralelas), bumpa `.percus-version` e
  verifica. Pré-requisitos de máquina: `git pull` no canon (docs lidos ao vivo via `PERCUS_CANON_DIR`)
  + update do plugin (tooling). Reforça: diretiva mora no canon, projeto referencia — nunca copia (cross-repo).
- `00_LEIA_PRIMEIRO.md` — nova linha de roteamento "Sincronizar projeto com o canon ATUAL" + data atualizada.

> Nota: o tooling novo (spec-analyze, consult-knowledge, checkpoint, PreCompact) só chega aos projetos
> após o **plugin ser republicado no marketplace** (o instalado é 6.16.1; o repo está à frente). Os
> docs/diretivas independem disso (chegam pelo `git pull` do canon).

---

## Changelog v6.21.0 — 2026-06-25

**Navegabilidade dos docs históricos (fecha a onda de limpeza). Canon-only.**

A auditoria de bloat apontou que docs históricos (sprints Fase 5 / v6.8, handoffs v6.10) sentam no
working tree sem marcação de "isto é história". Decisão: **não mover** (são referenciados por changelog
histórico + docs ativos como `01_REGRAS`/`UPGRADE_PARA_FASE7`, e `docs/superpowers/specs/` é o home ativo
de specs por convenção — mover quebraria links e reescreveria registro histórico). Em vez disso, marcadores:

- `docs/superpowers/README.md` — marca specs/plans como registro point-in-time + tabela das sprints concluídas + por que não foram movidos.
- `docs/handoffs/README.md` — marca handoffs de release como histórico aplicado.

Resultado: quem cai nesses diretórios vê na hora "isto é história, o estado atual é `CANON_VERSION.md`".
Risco zero, sem cirurgia de refs. Encerra a onda de limpeza (canon confirmado saudável: zero órfãos).

---

## Changelog v6.20.0 — 2026-06-25

**Ondas seguintes: política de deploy + frentes paralelas + limpeza. (Canon-only — plugin inalterado vs 6.19.0.)**

**Onda 8 — Política de deploy (ponto 8):**
- `01_REGRAS_INEGOCIAVEIS.md` **R24** — cadência de deploy: **milestone / fim do dia / sob demanda**, NÃO a cada processo. Resolve a dor "deploy a cada processo consome tempo e recursos". Inclui smoke test pós-deploy + rollback obrigatórios.
- `comandos/DEPLOY.md` — playbook: quando deployar + como (ref `02_INFRA` §6-10 Portainer/Swarm) + smoke (`curl -I` + `docker service logs`) + rollback (`docker service rollback`).
- `conhecimento/COMO_FAZER.md#deploy-vps` — stub preenchido com procedimento fundamentado.

**Onda 9 — Frentes paralelas + orquestrador (ponto 9):**
- `comandos/COMANDO_FRENTES_PARALELAS.md` — design canônico (a pilotar): worktrees + aba-diretora, ancorado em **foundational-first + tasks `[P]`** do spec-kit. Writer-unique protocol (cada arquivo um escritor), decomposition gate via conselho, merge serial ordenado pela diretora, pré-requisito de fundação `[5-T]` merged.

**Limpeza mínima (canon saudável — auditoria confirmou zero órfãos):**
- Drift de versão corrigido em `COMANDO_PROJETO_NOVO.md` (frontmatter aponta CANON_VERSION em vez de hardcode v6.7.0+).
- Datas de `ultima-atualizacao` adicionadas em `SETUP_CLAUDE_SETTINGS.md` e `UPGRADE_PARA_FASE7.md`.
- `SETUP_CODEX_REVIEWER.md` (DEPRECATED) **mantido** — referenciado por 4 arquivos; header DEPRECATED já sinaliza.

---

## Changelog v6.19.0 — 2026-06-25

**Spec-driven front-end + base de conhecimento + checkpoint de contexto.**

Três frentes ortogonais, validadas por pre-mortem do conselho (3 riscos de consenso mitigados antes de implementar). Adoção **seletiva** do spec-kit (github/spec-kit): aparafusa o front-end (spec+clarify+analyze) no back-end `[0]→[5-T]` existente, sem adotar as 7 fases nem a estrutura `.specify/`.

**Workstream A — Spec front-end + conselho Modo 5 (analyze):**
- `templates/spec.template.md` — spec por feature, WHAT/WHY tech-agnóstico (User Scenarios P1/P2/P3, FR-###, SC-###, edge cases, ≤3 NEEDS-CLARIFICATION).
- `templates/spec-checklist.template.md` — auto-validação de qualidade da spec.
- `providers/system-prompt-analyze.md` — detecção estruturada (cobertura FR/SC, ambiguidade, violação constituição, terminology drift, vazamento WHAT→HOW) com veredito PRONTA/AJUSTAR/BLOQUEADA.
- `commands/spec-analyze.md` — `/percus-review:spec-analyze`; 2 providers default, 3 se sensível/`--deep`; CRITICAL passa por fact-check F3 (R20).
- `council-orchestrator.{ps1,sh}` + `cross-claude.{ps1,sh}` — novo `-Mode analyze`.
- `feature-flow/SKILL.md` + `CHECKLIST_FEATURE_NOVA.md` — gate `[S]` **proporcional** (só feature não-trivial; trivial usa mini-spec) antes do `[0]`.
- `06_CONSELHO_PERCUS.md` — Modo 5 documentado + tabela de mapeamento spec-kit↔Percus (5 modos agora).

**Workstream B — Base de conhecimento cross-projeto:**
- `conhecimento/COMO_FAZER.md` (procedimentos-base) + `conhecimento/COMO_RESOLVER.md` (problema→solução, busca por classe de sintoma via `tags:`, semeado com incidentes conhecidos).
- `skills/consult-knowledge/SKILL.md` — lookup **semântico** (lê o arquivo + casa por classe, não grep literal).
- `01_REGRAS_INEGOCIAVEIS.md` **R23** — consultar antes de resolver, registrar depois. Ligado a `CHECKLIST_ENCERRAR_SESSAO.md` (passo 3.5) e ao `/checkpoint`.

**Workstream C — Checkpoint de contexto:**
- `skills/checkpoint/SKILL.md` (PRIMÁRIO) — sincroniza PLANO+HANDOFF+mock-audit, commita com review, emite prompt de retomada.
- `templates/RESUME_PROMPT.template.md`.
- `hooks/pre-compact-checkpoint.{ps1,sh,cmd}` — hook `PreCompact` backstop (contrato confirmado na doc oficial); loga fail-loud + `systemMessage`, não bloqueia. Registrado em `hooks.json`.

**Pre-mortem (riscos de consenso DeepSeek+Cross-Claude, mitigados):** (1) PreCompact falha silenciosa → `/checkpoint` primário + log fail-loud + contrato confirmado; (2) gate `[S]` vira drift → proporcional + custo escalonado; (3) COMO_RESOLVER grep falso-negativo → lookup semântico por classe.

---

## Changelog v6.18.0 — 2026-06-20

**Skills/Recipes/Personas por projeto — padrão gmp-cli adaptado (v6.18.0).**

Adoção da arquitetura de conhecimento local de [gmp-cli](https://github.com/lucianfialho/gmp-cli)
(`skills/` + `recipe-*` + `persona-*`) como padrão para todos os projetos Percus novos e existentes.

- **3 templates novos** em `templates/`:
  - `project-skill.template.md` — skill de domínio (capacidade específica do projeto)
  - `project-recipe.template.md` — workflow composto com critério de avanço + abort protocol
  - `project-persona.template.md` — agente especializado com leitura obrigatória + escaladas
- **`comandos/SETUP_PROJECT_SKILLS.md`** — comando completo com "cole no chat" + referência
  detalhada por tipo (skill vs recipe vs persona) + tabela de integração com percus-review.
- **`comandos/UPGRADE_ADICIONAR_SKILLS.md`** — guia dedicado para projetos existentes
  (Passo 0 diagnóstico → criação → registro no CLAUDE.md → review → commit).
- **`comandos/COMANDO_PROJETO_NOVO.md`** — novo passo 2.7 (skills locais) no fluxo greenfield.
- **`comandos/UPGRADE_PARA_FASE7.md`** — nova seção §8 com skills locais no upgrade de auth.
- **`comandos/UPGRADE_PARA_FASE6.md`** — forward reference para skills como próximo passo.

**Estrutura alvo em cada projeto:**
```
skills/
├── {domain}/SKILL.md
├── recipes/recipe-{workflow}/RECIPE.md
└── personas/persona-{role}/PERSONA.md
```

Skills locais complementam (nunca duplicam) o plugin `percus-review`:
plugin cobre cross-projeto (auth-consumer, security-audit, feature-flow);
skills locais cobrem conhecimento específico do produto (paths, convenções, integrações externas).

---

## Changelog v6.17.0 — 2026-06-20

**Propagação auth-service 2026-06-16 — itens faltantes no canon.**

- `PADRAO_AUTH_SERVICE.md` **B.6** — sessão durável: `#rt=` + `/otp/refresh` obrigatórios (consumer-side). Gap confirmado Coach: bridge sem `#rt=` → re-OTP a cada TTL do access token.
- `PADRAO_AUTH_SERVICE.md` **Seção K** — nova linha anti-padrão: bridge que lê só `#at=` e ignora `#rt=`.
- `auth-consumer/checklist.yaml` — novo check `BRIDGE-refresh-token-consumed` (high severity).
- `auth-consumer/SKILL.md` — novo anti-padrão `#rt=` + nota em C8.

_Nota:_ `02_INFRA §2.4.1` (JID/9º dígito) e `PADRAO §2.8` (branded magic abandonado) já foram absorvidos numa atualização anterior de 2026-06-20 — não duplicados aqui.

---

## Changelog v6.16.1 — 2026-05-30

**Fix: council usava caminho de arquivo FIXO (`/tmp/council-*.txt`) → prompt stale entre runs.**

Bug reportado por projeto (2026-05-30), **root cause confirmado por reprodução**: os command docs do conselho (`council-consult`, `council-brainstorm`, `council-pre-mortem`, `drift-detect`) mandavam o agente salvar a pergunta num **nome de arquivo fixo** `/tmp/council-*.txt`. No Windows `/tmp/...` resolve pra `d:\tmp\...`; quando a 2ª pergunta não sobrescrevia o arquivo, o orchestrator lia o prompt **VELHO** → o conselho "revisava a coisa errada de novo". (NÃO era cache do orchestrator — ele lê `Get-Content -Raw` fresco — NEM o `prompt_cache_hit_tokens` da DeepSeek, que é red herring de cache de prefixo server-side.)

- Os 4 command docs agora instruem **arquivo temp único por invocação** (`$env:TEMP` + GUID no Windows / `mktemp` no Unix), escrito e consumido na mesma invocação com cleanup. Idem pro `-CrossClaudeFile`. Stdin documentado como alternativa à prova de stale.
- Housekeeping: removidos 45 `council-*.txt` stale acumulados em `d:\tmp\` (dumping ground compartilhado entre sessões).
- Só docs de comando; `council-orchestrator` e providers **inalterados** (já liam fresco).

---

## Changelog v6.16.0 — 2026-05-30

**Integra o Padrão Auth Percus v2 (5 pilares) no canon como direção vigente com status de rollout.**

O time do auth-service entregou (supplement 2026-05-30, pós conselho 3/3) o **Padrão Auth Percus v2** — 5 pilares cross-projeto. Integrado nos docs permanentes do canon como **lei que os projetos DEVEM seguir**, com **status de rollout real por pilar** (a maioria ainda não em prod) e **janelas de breaking change** preservadas. Sem mudança de comportamento de tooling.

- **`PADRAO_AUTH_SERVICE.md` — nova Seção L:** tabela-mestra de rollout + L.1-L.5 (P1 magic+OTP combinado, P2 Painel vira consumer, P3 lib `@percus/auth-ui`, P4 enforcement contract-tests+catálogo, P5 telemetria OTel) + sequência de sprints + sprint hardening encerrado + deps cross-repo read-only. Baseline Seções A-K (contrato congelado) **intacto**. Add **B.1.v2** (signup `name+phone+email` required via `/internal/identities/v2` — breaking, ≥60d, major bump `percus-auth`) sem mexer no V1. Seção G nota Pilar 1 preservando TTLs e mitigações.
- **`01_REGRAS_INEGOCIAVEIS.md`:** notas de pilar com status em R7/R14/R15/R17/R19 (sem regra numerada nova).
- **Contracts + infra sync:** `error-codes.md` (nota `/v2`, sem error_code novo), `02_INFRA` (dual-verifier 7d genérico + 3-4 sem Painel; nota Pilar 1), `approved-evolution-instances.yaml` (fix ref morta `..._INTEGRATION_V2`), `CHECKLIST_AUTH_NOVO_PROJETO.md` (signup name+phone+email).
- **`05_FEATURE_TRACKING.md`:** registra 5 slugs dos pilares (em rollout, sem claim de `adopted`). ADR nasce no `auth-service` (não no canon, por convenção).
- Housekeeping: deletado o supplement temp `PADRAO_AUTH_PERCUS_2026-05-30.md` após integração.

**Honestidade factual:** Painel NÃO migrou, lib `@percus/auth-ui` NÃO publicada, OTel/SigNoz NÃO subiu — documentado como status de rollout, não como fato consumado. **Review 3-membros adiado** (`council-orchestrator` com bug de prompt stale, registrado pra avaliação).

---

## Changelog v6.15.0 — 2026-05-30

**Governança: R11 sem exceção pro kit + refresh de docs + housekeeping cross-repo.**

Release de higiene pós-v6.14.0 — **sem mudança de comportamento de tooling** (o gate de R11 já era uniforme). Consolida 3 mudanças no canon. Versão reservada `6.13.0` segue pulada (piloto cascata cross-repo, não bumpa o canon).

- **R11 sem exceção estrutural pro kit** (`01_REGRAS_INEGOCIAVEIS.md`): a isenção que dispensava `_Novo_Projeto/` de review cross-provider foi removida. Era **letra morta** — o hook `pre-commit-check` nunca teve carve-out pro kit (aplica o gate de ≤5min uniformemente, bloqueou commits do próprio canon). E a premissa ("kit é convenção, não código de produção") caducou: o kit shippa código executável real (plugin: scripts + ~12 hooks ×3 shells + 123 testes), com bugs reais já pegos por review (regex de parse no `fact-check.ps1`, ASCII/PS5.1). Os requisitos (a) plano explícito (b) revisão do usuário (c) consistência cruzada permanecem como **aditivos** ao review, não substitutos. Trade-off aceito: DeepSeek passa ao caminho crítico de todo commit do kit; válvula = `PERCUS_HOOKS_DISABLED`. **Não afeta projetos consumidores** — a exceção só valia pro próprio kit.
- **Refresh completo do corpo do README:** mapa de pastas reescrito contra a árvore real (faltavam `05`/`06`/`PADRAO_AUTH_SERVICE`/`AMBIENTE`/`tools`/`infra`/`docs/{handoffs,contracts}` + `settings.template.json` + `login-ui/` + subdirs do plugin); Fase 5 "branch only" → absorvida em main; ref morta a `_AUDIT_2026-05-15.md` removida; seção do plugin 2 → 3 membros (conselho + Llama/Groq); onboarding "Fase 4" → genérico/Fase 7. O bump anterior (`bea45ba`) só corrigira o header de versão — este completa o corpo.
- **Housekeeping cross-repo:** removido `COACH_AUDIENCE_WA_OVERRIDE_2026-05-15.md` (handoff específico do Plexco Coach) da raiz — canon não hospeda artefato de projeto; original vive em Plexco Tasks. ⚠️ continha API key real do Evolution → **rotacionar** (permanece no histórico git até scrub).

**Sem código novo / sem testes novos** — mudanças só em docs/regra.

---

## Changelog v6.14.0 — 2026-05-30

**Otimização Groq na pipeline do conselho: triagem de fact-check (Vetor B) + tie-breaker (Vetor D).**

Fase 4 do plano v6.11.0→v7.0.0. Explora latência/custo do Groq-Llama onde faz sentido, sem tocar criatividade (brainstorm segue Sonnet) nem precisão de código (DeepSeek). **6.13.0 pulado de propósito** — reservado pro piloto cascata (cross-repo Plexco Tasks, não bumpa o canon). Ambas otimizações **opt-in / gated — zero mudança por default**.

**Vetor B — triagem Llama upstream do Sonnet:**
- Novo `scripts/fact-check-triage.ps1` + `.sh`: classifica cada finding `[SEV: risco|bug]` em **PLAUSIVEL** (passa) ou **SUSPEITA**/unverified (escala pro Sonnet). Em dúvida → SUSPEITA. `-Wrapper` injetável (testável offline). 9 testes Pester + smoke `.sh`.
- `fact-check.ps1` integra via `$env:PERCUS_FACTCHECK_TRIAGE`: ausente=**OFF** (histórico); `1`/`shadow`=dual-run (Llama+Sonnet, loga concordância em `.deepseek/metrics/factcheck-triage.jsonl`, output inalterado); `gate`=Llama plausível pula o Sonnet (economia). **Sem promoção automática shadow→gate.** 5 testes de integração (default-off inalterado / shadow loga / gate pula / suspeita escala).
- **Bug latente corrigido:** o regex de parse de findings do `fact-check.ps1` usava `(?ms)…[^\[]*?…$` — o flag `m` fazia `$` casar em todo fim-de-linha, truncando cada bloco no 1º EOL (file_path/descrição vazios). Corrigido pra `(?s)…\.*?…\z` (`.ps1` e `.sh`). Teste de regressão adicionado.

**Vetor D — tie-breaker Llama no conselho:**
- Nova lib `scripts/council-tiebreaker.ps1` (funções puras, dot-sourcável): `Test-CouncilNeedsTieBreaker` (gatilho: exatamente 2 providers OK, groq-llama NÃO entre eles, `premise_validity` divergente com ≥1 não-vazio) + `Invoke-LlamaTieBreaker`. 10 testes.
- `council-orchestrator.ps1`/`.sh` dot-sourceiam a lib e emitem `tie_breaker_invoked` + `tie_breaker` no JSON. Resultado é **"convergência 2/3 informal — tie-breaker fraco"**, operador decide. Bloco `.sh` é não-fatal (set +e local) — nunca aborta o output principal.
- `06_CONSELHO_PERCUS.md` (seção "Otimizações Groq") + `commands/council-consult.md` (síntese trata `tie_breaker_invoked`) documentam ambos. Skill `feature-flow` inalterada.

**Descartados (consenso 2/2 do conselho):** Vetor A (brainstorm Llama) e Vetor C (geração de código Llama).

**TDD (R9):** +24 testes novos. Fonte `.ps1` 100% ASCII (PS 5.1). Smoke `.sh` (triagem) via git-bash + python3.

**Pendências (operador):** (1) soak: rodar `PERCUS_FACTCHECK_TRIAGE=1` (shadow) ~30 dias em reviews reais e conferir ≥90% de concordância Llama-PLAUSIVEL vs Sonnet-CONFIRMADO antes de ativar `gate`. (2) **Parity gap conhecido:** a integração da triagem no `fact-check.sh` (modos shadow/gate) NÃO foi portada — só o fix do regex landou no `.sh`; o `.ps1` tem a feature completa (operador roda Windows). (3) `council-orchestrator.sh` Vetor D não foi testado neste host (sem jq local) — validar em Unix.

---

## Changelog v6.12.0 — 2026-05-30

**Enforcement do tracking `[5-T]`: warn pre-commit + drift check on-stop.**

Fase 2 do plano v6.11.0→v7.0.0 ([acabei-de-perceber-que-quirky-toast.md](D:/Claud Automations/.claude-home/plans/acabei-de-perceber-que-quirky-toast.md)). Resolve a dor comprovada do `[0]→[5-T]`: até v6.11 o enforcement era só documental — nenhum hook validava que um `[5-T]` declarado teve ciclo CRUD real, e nada checava se `PLANO.md` e `HANDOFF.md` concordam. Resultado era drift silencioso entre o que o PLANO declara e o que o código faz.

**2 hooks novos (sem promoção automática warn→block — decisão do conselho):**

- **`crud-evidence-warn.ps1`/`.sh`/`.cmd`** (PreToolUse:Bash, **warn-only / exit 0**): quando o staged diff de `PLANO.md`/`HANDOFF.md` adiciona uma feature `[5-T]` e o `git commit` não carrega o trailer `CRUD-verified: YYYY-MM-DD`, avisa no stderr e loga em `.deepseek/crud-warn.log` (instrumentação pro soak). Nunca bloqueia. Reformat/EOF-newline que re-adiciona uma linha `[5-T]` idêntica NÃO dispara (só transição real). Skip: `PERCUS_SKIP_CRUD_WARN=1`.
- **`state-drift-check.ps1`/`.sh`/`.cmd`** (Stop event, **bloqueia / exit 2**): compara o status de cada feature entre `docs/PLANO.md` (fonte da verdade) e `HANDOFF.md`. Bloqueia o encerramento se alguma feature tem tag divergente (ex: `[5-T]` no PLANO vs `[3-H]` no HANDOFF), nomeando a feature e as duas tags. **Conservador (fail-open):** só bloqueia em match confiável de nome normalizado; qualquer erro de parsing → exit 0. Skip: `PERCUS_SKIP_DRIFT_CHECK=1`.

**Parsing conservador:** PLANO via bullets `- \`[tag]\` Nome — desc` (a tabela de Legenda é ignorada por ser markdown table, não bullet); HANDOFF via tabela escopada à seção `## Status de Features`. Normalização de nome remove marcações visuais (🎨🤖✓✅) e acentos/em-dash. Fonte dos hooks 100% ASCII de propósito — PS 5.1 lê `.ps1` sem BOM como cp1252 e quebraria em string literal não-ASCII (smart-quotes); os chars de matching vêm de code point via `[char]`.

**Skill + canon:**
- `skills/feature-flow/SKILL.md` — ao marcar `[5-T]`, instrui atualizar `PLANO.md` **e** `HANDOFF.md` na mesma operação + incluir o trailer `CRUD-verified:` no commit (elimina a classe de drift por origem).
- `01_REGRAS_INEGOCIAVEIS.md` R2 — nova subseção documentando o trailer e os dois hooks.

**TDD (R9):** `tests/crud-evidence-warn.tests.ps1` (13 testes) + `tests/state-drift-check.tests.ps1` (13 testes). Suite total: 98/98 verde. Smoke cruzado validado: `.ps1` sob pwsh 7 **e** Windows PowerShell 5.1 (caminho real do `.cmd`), `.sh` sob git-bash + python3.

**Pendente (soak):** rodar 14 dias em ≥2 projetos coletando quantas vezes `warn` e `block` dispararam (adesão real + drift que estava silencioso). Promoção warn→block só sob pedido explícito do operador após o soak.

**Não incluído:** `COACH_AUDIENCE_WA_OVERRIDE_2026-05-15.md` permanece na raiz (operador ainda não confirmou que colou no Plexco Coach — fechar em release cosmética futura).

---

## Changelog v6.11.0 — 2026-05-30

**Limpa cosmética do canon + template canônico de `.claude/settings.json`.**

Fase 1 do plano v6.11.0→v7.0.0 ([acabei-de-perceber-que-quirky-toast.md](D:/Claud Automations/.claude-home/plans/acabei-de-perceber-que-quirky-toast.md)) — refactor incremental do canon. Esta release é cosmética + setup canônico de settings; zero breaking pros consumidores.

**Consolidação AUTH (3 → 1 arquivo):**
- `PADRAO_AUTH_SERVICE_INTEGRATION_V2.md` → renomeado para `PADRAO_AUTH_SERVICE.md` (versionamento volta pro git, sai do nome de arquivo).
- `AUTH_SERVICE_PATTERNS_LEARNED_2026-05-15.md` → removido (já absorvido na Seção I do consolidado desde v6.9.x).
- `REVIEW_AUTH_INTEGRATION_2026-05-15.md` → removido (review de momento da sessão 35; decisões já refletidas no consolidado).
- Refs atualizadas em: `01_REGRAS_INEGOCIAVEIS.md`, `checklists/CHECKLIST_AUDIENCE_NOVA.md`, `comandos/COMANDO_PROJETO_NOVO.md`, `docs/contracts/{error-codes,redirect-reasons,MIGRATION_V1_TO_V2}.md`.

**Stale removidos da raiz** (artefatos operacionais de sessão, não canon — git history preserva conteúdo):
- `_AUDIT_2026-05-15.md`, `_AUDIT_2026-05-17_eixo-f.md`, `_AUDIT_2026-05-17_eixo-f-pos-entrega.md`
- `baseline-2026-05-17.md`, `baseline-2026-05-17-v2.md` (eram untracked)
- `diagnostico-disco-c-2026-05-15.md`

**NOVO — template canônico de settings:**
- `templates/settings.template.json` — `bypassPermissions` + `allow:*` (mode operador único Rodrigo), `additionalDirectories` portáveis (`${env:USERPROFILE}` em vez de placeholder), `enableAllProjectMcpServers: true`, 3 hooks padronizados (SessionStart GATE INICIO / UserPromptSubmit GATE VISUAL com regex refinada / Stop ENCERRAMENTO).
- `comandos/SETUP_CLAUDE_SETTINGS.md` — runbook passo-a-passo de aplicação em projeto novo OU existente, incluindo drift detection e anti-padrões.
- **GATE VISUAL regex** refinada após observar falsos-positivos recorrentes na sessão de planejamento desta release: era `(landing page|p[aá]gina inicial|redesign|...|paleta|layout novo)` — disparava em qualquer menção genérica de design; agora `(gerar (mockup|wireframe|design)|criar tela nova|redesenhar.*(p[áa]gina|tela)|v0\.dev|claude\.ai/design|hero section|reestilizar.*UI|landing page (nova|do zero)|mockup do figma)` — exige verbo de criação + objeto visual concreto.
- **GATE INICIO + ENCERRAMENTO** agora explicitam "Se eh canon/lib/tooling, ignore." pra silenciar ruído em sessões onde `HANDOFF.md`/`docs/PLANO.md` não existem (canon próprio, libs, tooling).

**00_LEIA_PRIMEIRO.md** ganha 2 linhas novas na tabela de roteamento:
- "Configurar `.claude/settings.json` canônico" → `comandos/SETUP_CLAUDE_SETTINGS.md`
- "Integrar com `auth-service`" → `PADRAO_AUTH_SERVICE.md`

**NÃO incluído nesta release** (deliberadamente):
- `COACH_AUDIENCE_WA_OVERRIDE_2026-05-15.md` permanece na raiz do canon — é handoff destinado ao Plexco Coach. Operador reforçou (2026-05-30): nunca tocar em projetos fora do CWD; mecanismo canônico é entregar caixa de texto pro operador colar manualmente. Caixa será entregue ao fim desta release; arquivo será deletado em v6.11.1 após confirmação.
- `templates/login-ui/` permanece intacto — análise revelou que pasta tem só 21 arquivos tracked (o "3155" inicial era `node_modules/` untracked). Login-ui é canon legítimo, alinhado com `auth-service/libs/node` via `@percus/auth`.

**Refs aprovação:**
- Plano completo: `D:/Claud Automations/.claude-home/plans/acabei-de-perceber-que-quirky-toast.md`
- Conselho consult cascata 3 níveis (2026-05-30 11:38): consenso 2/2 Opção A.
- Conselho pre-mortem do plano original (2026-05-30 11:42): identificou riscos críticos endereçados nesta versão (cascata virou experimento condicional; login-ui mantido; enforcement sem promoção automática).
- Conselho consult otimização Groq (2026-05-30 11:55): Vetor B + D adotados pra v6.14.0 (paralelo); Vetor A + C descartados.

---

## Changelog v6.10.0 — 2026-05-26 (noite)

**R22 v2 — bloco de 20 portas + range expandido 3000-9999.**

Decisão: bloco de 10 portas era apertado pra projeto full-stack real (Vite + Storybook + Playwright + backend FastAPI + worker + Postgres local + Redis local consomem 7-8 offsets, quase zero margem). Bumpamos para **20 portas/projeto** e expandimos range global de `3100-4090` (100 projetos) para `3000-9999` (~349 projetos).

**Breaking — todos os projetos já alocados foram re-alocados.** Snapshot pré-v6.10 (`painel-gestao` 3100, `tiatendo` 3110, etc.) virou (`painel-gestao` 3000, `tiatendo` 3020, etc.). Operador precisa re-rodar `/percus-review:port-allocate` em cada projeto, atualizar `.env` e configs (vite/next/compose). Documentado em `docs/handoffs/HANDOFF_CONSUMIDORES_v6.10.md`.

**Cross-repo Painel:** mudanças no Painel ficam descritas em `docs/handoffs/HANDOFF_PAINEL_v6.10.md` — canon **não** comita lá (cross-repo write protocol). Operador aplica manualmente:
- Migration nova (drop CHECK antigo, zera `port_base`, re-aloca por `ORDER BY id`, novo CHECK `BETWEEN 3000 AND 9980 AND port_base % 20 = 0`).
- `catalogEngine.py:77-79` constantes (`PORT_ALLOC_RANGE_START=3000`, `PORT_ALLOC_RANGE_END=9980`, `PORT_ALLOC_BLOCK_SIZE=20`).
- `docs/PORT_ALLOCATION_CONSUMER_GUIDE.md` snapshot + seção concorrência explícita.
- Tests `test_portAllocate.py` ajustados pros novos números.

**Concorrência (documentada explicitamente):** o endpoint já era seguro via `pg_advisory_xact_lock(4242)` + UNIQUE INDEX `uq_projects_port_base`. 2 consultas simultâneas do mesmo slug → mesmo `port_base` (idempotência). 2 consultas simultâneas de slugs distintos → blocos distintos garantidos pelo lock; UNIQUE INDEX é rede de segurança. Nada muda no código — só fica documentado pra agentes/consumidores não duvidarem.

**Canon — arquivos tocados nesta release:**
- `01_REGRAS_INEGOCIAVEIS.md` R22 — bloco 20, range 3000-9999, tabela de 12 offsets nomeados + reserva, seção "Garantia de unicidade sob concorrência".
- `02_INFRA_E_STACK_PERCUS.md` §5.5 — mesma tabela, exemplos atualizados (port_base=3140 next free).
- `plugin/percus-review/skills/port-allocate/SKILL.md` — banner breaking v6.10, exemplos com tiatendo 3020·3039.
- `plugin/percus-review/scripts/port_allocate.py` — `BLOCK_SIZE=20`, `RANGE_START=3000`, `RANGE_END=9980`, fallback ajustado.
- `docs/handoffs/HANDOFF_PAINEL_v6.10.md` (novo) — passo-a-passo pra aplicar no Painel.
- `docs/handoffs/HANDOFF_CONSUMIDORES_v6.10.md` (novo) — passo-a-passo pra cada projeto consumidor re-alocar.

**Snapshot real pós-migration** (ordem por `id` UUID divergiu do otimista do handoff — verdade do banco):

| slug | port_base | range |
|---|---|---|
| familia-milionaria | 3000 | 3000·3019 |
| ghl-evolution | 3020 | 3020·3039 |
| robo-vendas | 3040 | 3040·3059 |
| zap-disparador | 3060 | 3060·3079 |
| tiatendo | 3080 | 3080·3099 |
| painel-gestao | 3100 | 3100·3119 |
| social-midia | 3120 | 3120·3139 |

**Próximo bloco livre:** 3140·3159.

**Deploy Painel confirmado:** imagem `ads4pros-api:fase7-20260526b` (sha `39fc67b49cd7`) vivo em prod. Commits Painel: `db8f3d6` (feat R22-v2) + `5eb9664` (docs snapshot real). Smoke E2E ok: `/health` 200, `port-allocate` idempotente, bloco-de-20 confirmado por `kind:new` saltar de 3120→3140. Backup `pg_dump --data-only -t projects` salvo na VPS antes da migration (rollback procedure no §4 do handoff Painel).

---

## Changelog v6.9.1 — 2026-05-26 (tarde)

**Sync com Painel pós-deploy R22.**

Após a sessão Painel deployar a v6.9.0 em prod (imagem `ads4pros-api:fase7-20260526a`, endpoint vivo, 7 projetos já alocados de 3100 a 3169), a Painel publicou `docs/PORT_ALLOCATION_CONSUMER_GUIDE.md` consolidando o padrão operacional real. O canon-side estava com 3 desvios em relação ao guia operacional:

1. **Tabela de offsets divergente.** Canon v6.9.0 pensava em "full-stack" (`+0` front, `+1` back, `+2` worker, `+3` admin UI, `+4` mailhog). Painel mapeou ferramentas reais do dev frontend Vite (`+0` dev server, `+1` preview, `+2` Storybook, `+3` Playwright UI, `+4` mock/MSW, `+5` outro daemon). Como a stack default Percus é Vite + frontend e a convenção é **sugestão** (não trava), o canon foi alinhado com a Painel. Full-stack continua livre pra mapear `+1` como backend em `docs/PORTS.md` do projeto.
2. **`strictPort: true` não era pré-requisito explícito.** Sem isso o Vite cai pra ephemeral e a alocação não tem efeito — exatamente o bug que motivou R22. Agora obrigatório em R22 gate 4.
3. **Estado do endpoint vago.** Canon ainda dizia "fallback é default" — invertido: endpoint vivo é o padrão, fallback é exceção rara.

Arquivos sincronizados em [commit a confirmar]:
- `01_REGRAS_INEGOCIAVEIS.md` R22 — tabela de offsets, `strictPort: true` no gate, referência ao consumer guide, anotação de auditoria visual via `gestao.ads4pros.com/projetos.html`.
- `02_INFRA_E_STACK_PERCUS.md` §5.5 — mesma tabela, exemplos de config alinhados (Vite strictPort, Next `--port`, Storybook `-p`, Playwright `--ui-port`).
- `plugin/percus-review/skills/port-allocate/SKILL.md` — exemplos por stack, referência ao consumer guide, badge UI.
- `plugin/percus-review/scripts/port_allocate.py` — docstring atualizada (endpoint vivo, fallback como exceção).

**Próximo bloco livre no momento desta release:** 3170. 7 projetos já alocados (snapshot vivo em [gestao.ads4pros.com/projetos.html](https://gestao.ads4pros.com/projetos.html)).

**Roadmap v6.10+** (registrado pelo guia Painel, ainda fora de escopo):
- Expandir constraint `chk_projects_port_base_range` quando passar de 100 projetos.
- Liberação de bloco quando projeto é desativado (hoje a coluna fica órfã).
- Dashboard de detecção de colisões via `lsof -i :PORT` em healthcheck local.

Princípio reforçado pela sincronização: **quando canon e Painel divergem em ponto operacional, Painel vence** — é o que está vivo em produção. Canon documenta o "porquê"; Painel documenta o "como agora".

---

## Changelog v6.9.0 — 2026-05-26

**R22: alocação central de portas locais via Painel.**

Bug: dois projetos Percus colidiram na porta `52924` (ephemeral atribuído por
Vite/Node sem `strict-port`). Causa estrutural: Far-West de portas — cada projeto
inventava as suas (3000 Next + 8000 FastAPI + 5273 Vite + 3100 Node + ...), sem
padrão cross-projeto.

**Solução: source of truth no Painel + bloco de 10 portas por projeto.**

Cada projeto Percus recebe um `port_base` único alocado pelo Painel (`projects.port_base INT UNIQUE` partial). Bloco de 10 portas cobre frontend (+0), backend (+1), worker (+2), reserva (+3..+9). Range global 3100-4090 = 100 projetos.

**Lado Painel** (cross-repo, autorizado em voz alta nesta execução; ver plano `analisa-essa-devolutiva-e-floofy-candy.md`):

- Migration `execution/database/migration_port_base.sql`: `ALTER TABLE projects ADD COLUMN port_base INT NULL` + UNIQUE index parcial + CHECK constraint do range.
- Engine `allocatePortBase(slug, name)` em `execution/engine/catalogEngine.py`: idempotente, serializado via `pg_advisory_xact_lock`, auto-cria projeto se name fornecido.
- Endpoint `POST /admin/projects/port-allocate` em `execution/api/catalogRoutes.py`: header `X-Internal-Auth` (mesma key de `/admin/catalog/ingest`).
- Tests integration em `tests/test_portAllocate.py` (cobertos: auto-create, idempotência, alocação sequencial, erro sem name).
- **Pendência operador:** aplicar migration na VPS (`psql ... -f migration_port_base.sql`) e reiniciar API container.

**Lado canon** (escopo deste commit):

- Skill `percus-review:port-allocate` para projetos novos + migração de legados.
- Wrapper `plugin/percus-review/scripts/port_allocate.py` (Python primary, mesmo padrão de `catalog_publish.py`):
  - Consulta Painel; fallback `hash(slug) % 100 → 3100 + hash*10` se offline.
  - Cache local `.percus-ports.json` versionado em git (`unverified: true` se fallback).
  - Idempotente; cache hit verified faz short-circuit.
- R22 em `01_REGRAS_INEGOCIAVEIS.md` + anti-padrões 29-30 na lista.
- Seção 5.5 em `02_INFRA_E_STACK_PERCUS.md` com tabela canônica de offsets.
- Passo 2.5 em `comandos/COMANDO_PROJETO_NOVO.md` (alocar port_base após templates).

**Pre-mortem do conselho** (DeepSeek + Llama; Cross-Claude falhou 400 nesta rodada — consenso 2/2):

- **Risco crítico identificado e mitigado:** plano original entregava canon antes da Painel, deixaria a ferramenta quebrada. Mitigação: ordem invertida — Painel-side primeiro, canon-side depois.
- Riscos aceitos como dívida documentada: hash collision ~1% (reconcile detecta); merge conflict em `.percus-ports.json` offline em branches paralelas (git força resolução); resistência adoção legados (1 projeto-piloto serve de exemplo).

**Próximos passos (operador, fora deste commit):**

1. Aplicar `migration_port_base.sql` na VPS + reiniciar API (Painel).
2. `curl -X POST .../admin/projects/port-allocate -d '{"slug":"test-foo","name":"Test Foo"}'` → confirmar `{port_base: 3100, ...}`.
3. Rodar `port-allocate` em 1 projeto piloto (Plexco Tasks recomendado), ajustar `vite.config` + `docker-compose` para usar `process.env.PERCUS_PORT_BASE`.
4. Documentar exemplo do piloto em UPGRADE_PARA_FASE8 (futuro).

---

## Changelog v6.8.4 — 2026-05-23

**Fix(deepseek-review): `curl` argv mangla UTF-8 em git-bash Windows + AGENTS.md tolerante a CP1252.**

Bug: o pre-commit hook quebrava com `messages[0].content: invalid unicode code
point at line N col M` da API DeepSeek. Reproduzido nesta própria sessão durante
implementação do fix — mesmo SEM `AGENTS.md` presente, o erro acontecia, o que
descartou a hipótese inicial de que era só encoding de `AGENTS.md`.

**Root cause real (descoberto via reprodução ao vivo):** o `curl` 8.18 do git-bash
recebe argv via Windows API (`CreateProcessW`), que reencoda UTF-8 → CP1252 → UTF-8
e quebra sequências multi-byte (`Você`, `código`, `padrão`, etc.) que existem no
próprio `SYSTEM_PROMPT` do script. O body JSON sai válido do `jq`, mas chega
corrompido na API. Teste empírico: passar o mesmo body via `--data-binary @file`
ou stdin funciona perfeito; via `--data-binary "$BODY"` (argv) falha.

Fix em [plugin/percus-review/scripts/deepseek-review.sh:126](plugin/percus-review/scripts/deepseek-review.sh):
`printf '%s' "$BODY" | curl ... --data-binary @-` — body vai por stdin, contorna
o argv mangling do Windows. Esse é o fix principal.

Fix complementar em [plugin/percus-review/scripts/deepseek-review.sh:71](plugin/percus-review/scripts/deepseek-review.sh):
normalização UTF-8 defensiva de `AGENTS.md` via `iconv` (UTF-8 com `-c`, fallback
CP1252, fallback `cat`). Mantém o pipeline robusto se o `AGENTS.md` do
projeto-cliente também estiver fora de UTF-8 — independente do argv mangling.

Fix simétrico em [plugin/percus-review/scripts/deepseek-review.ps1:76](plugin/percus-review/scripts/deepseek-review.ps1):
`Get-Content -Encoding UTF8` explícito com fallback CP1252. A `.ps1` já passava o
body por `Invoke-RestMethod -Body $bodyBytes` (bytes UTF-8 explícitos, L113), então
o caminho do argv mangling não a afeta — só a leitura do `AGENTS.md` precisava de
guard.

**Decisão do conselho** (`/percus-review:council-consult` com DeepSeek + Llama):
consenso 2/2 em "normalização defensiva" (sobre o pedaço do `AGENTS.md`). O fix
real (argv → stdin) emergiu durante teste de fumaça, após o conselho. Ambos os
caminhos ficaram no v6.8.4 porque cobrem causas distintas do mesmo sintoma.

**Lição registrada:** rodar o próprio `deepseek-review.sh` localmente antes de
declarar fix completo. O bug foi reproduzido apenas porque tentei satisfazer o
hook de R11 e o script falhou em ambiente local — sem isso, teria comitado
"fix-AGENTS.md-CP1252" sem ter corrigido o caminho principal.

**Não inclui** (registrado como follow-up v6.8.5): melhorar mensagem de erro
quando `curl` retorna 400 do DeepSeek — hoje só diz "chamada API falhou", deveria
exibir o body pra debug ser segundos em vez de minutos.

---

## Changelog v6.8.3 — 2026-05-20

**Novo comando `/percus-review:version`.**

`commands/version.md` — comando que mostra a versão do plugin `percus-review`
instalado na sessão atual, o changelog condensado, e — se o canon estiver
alcançável (`$PERCUS_CANON_DIR` ou path padrão) — compara com `.percus-version`
e sinaliza drift (ex: "plugin instalado v6.8.0 mas canon já em v6.8.3 — atualize
pela UI do marketplace").

Motivação: a skill foi adiada 2× (v6.7.0, v6.7.2) com a nota "re-avaliar se
houver 3ª ocorrência de confusão de versão". As ocorrências chegaram — incidente
v6.7.0-vs-v6.7.1 (memória `check-origin-before-resume`) + o cache do plugin
ficando defasado do canon durante a própria Sprint v6.8. O comando torna o drift
visível sob demanda em vez de exigir leitura manual do `CANON_VERSION.md`.

`disable-model-invocation: true` — é comando de operador, não auto-invocável.

---

## Changelog v6.8.2 — 2026-05-20

**Smoke v6.8 — corrige nome da lib nos templates e scaffold.**

Smoke ponta-a-ponta dos entregáveis da Sprint v6.8 (Frente B `templates/login-ui/`
+ Frente C `scaffold-percus-project`) rodando o scaffold contra um projeto Next.js
real. Dois bugs encontrados:

1. **Nome da lib errado.** A lib Node real é `@percus/auth` (scoped), com toda a
   API de tenant (`useTenant`, `TenantProvider`, `getTenantConfig`, `TenantConfig`)
   exportada do **export root**. Os templates e o scaffold importavam
   `percus-auth/tenant` — pacote unscoped + subpath `/tenant` que não existe no
   `exports` da lib. **Todo projeto scaffoldado quebraria na resolução de import.**
   Origem: o plano da Frente D assumiu `percus-auth` unscoped; Frentes B/C
   herdaram. Fix: `percus-auth/tenant` → `@percus/auth` em `login-card.tsx`,
   `support-link.tsx`, `vitest.config.ts`, `login-card.test.tsx`, stub,
   `README.md`, `scaffold-percus-project.ps1/.sh` (`npm install @percus/auth`),
   e nos code-blocks de `MIGRATION_KIT_AUTH.template.md` (`@percus/auth/express`,
   `@percus/auth/next`). Lib Python segue `percus-auth` (correto — pip).
2. **`.env.example` incompleto.** O passo 6 do `README.md` (mount do
   `TenantProvider`) lê `NEXT_PUBLIC_PERCUS_AUDIENCE_FALLBACK` e
   `NEXT_PUBLIC_PERCUS_PRODUCT_FALLBACK`, mas o `.env.example` não as definia
   (o scaffold já tinha a substituição, sem alvo). Adicionadas.

Scaffold validado: re-scaffold produz `import { useTenant } from "@percus/auth"`.
Template login-ui: 10/10 testes vitest verdes.

---

## Changelog v6.8.1 — 2026-05-20

**Fix mock-scan — falso-positivo R3 em palavras acentuadas.**

Sintoma: durante a Sprint v6.8 Frente B, o hook `mock-scan` bloqueou um commit
legítimo flagrando `aria-label="Método de login"` como "TODO/FIXME/XXX/HACK
pendente" — a palavra portuguesa "mé**todo**" contém "todo".

Causa raiz (dupla):
1. `Get-PercusStagedContent` (`_helpers.ps1`) lia o output do `git show` com a
   codepage OEM (cp850/cp437) em vez de UTF-8. O "é" (UTF-8 `C3 A9`) virava 2
   bytes não-word → criava uma word-boundary falsa antes de "todo".
2. O padrão `\b(?:TODO|FIXME|XXX|HACK)\b[: ]` casava case-insensitive (default
   do `-match`/`grep -i`), então "todo" minúsculo dentro de "método" casava.

Fix:
- `Get-PercusStagedContent` força `[Console]::OutputEncoding = UTF8` ao ler o git.
- Markers viram **case-sensitive** via grupo `(?-i:TODO|FIXME|XXX|HACK)` nos dois
  hooks (`.ps1` e `.sh`) — TODO/FIXME/XXX/HACK são convenção maiúscula; matching
  insensível era a causa latente. Markers reais (`// TODO:`, `# FIXME `) seguem
  bloqueando.
- `mock-scan-pre-commit.ps1` ganha dual stdin path (`[Console]::In` + fallback
  `$input`), igual ao `pre-commit-check.ps1` — torna o hook testável via Pester.
- Comentário obsoleto em `external-action-guard.ps1` removido ("F3 Sprint 2" —
  F3 entregue na v6.7.0).
- Novo `tests/mock-scan.tests.ps1` — 6 testes de regressão. Suite: 72/72.

---

## Changelog v6.8.0 — 2026-05-20

**Sprint v6.8 — Canonização do padrão auth** (5 frentes paralelas A-E).

**Breaking changes:**
- R7.5: audience naming **MUST** ser kebab-case. Audiences legadas com underscore precisam ser migradas via `UPGRADE_PARA_FASE7.md`.
- Lib `percus-auth` bump 0.3.x → 0.4.0 (novos hooks `useTenant`/`TenantProvider`).
- Schema `auth.audiences` ganha 8 colunas (branding + origins + alias_slugs).

**Novidades:**
- Endpoint público `GET /tenants/by-origin` no auth-service (rate-limited).
- Templates `templates/login-ui/` canônicos extraídos do Plexco Tasks (parametrizado por tenant).
- Script `tools/scaffold-percus-project.ps1`/`.sh` idempotente.
- `COMANDO_PROJETO_NOVO.md` aciona scaffold + checklist humano.
- `UPGRADE_PARA_FASE7.md` novo.
- R7.5 (kebab-case enforcement) + R7.6 (tenant detection) cravadas no canon.

**Refs:**
- Spec: [docs/superpowers/specs/2026-05-19-sprint-v6.8-auth-canonization-design.md](docs/superpowers/specs/2026-05-19-sprint-v6.8-auth-canonization-design.md)
- Planos: [docs/superpowers/plans/2026-05-19-sprint-v6.8-frente-*.md](docs/superpowers/plans/)

---

## Changelog v6.7.2 — 2026-05-19

**Cross-repo R11 + diagnostic hardening** (pós-incidentes consolidados 2026-05-19).

Contexto: sessão Plexco Tasks reportou dois incidentes além do incidente 2026-05-18 já endereçado em v6.7.0:
- **Incidente 2** (wrapper auto-rename + branch autônoma): plugin v6.7.1 já não reproduz — `hooks.json` não registra `PostToolUse:Edit` e nenhum script cria branches. Coberto agora por **invariantes de teste** que falham se essa propriedade regredir.
- **Incidente 3** (hook freshness lê CWD em vez de git toplevel, quebra R11 cross-repo): **corrigido**.

**Mudanças:**

- **Proposta F (hook cross-repo):** `hooks/pre-commit-check.ps1` e `.sh` parseiam `cd <dir> && git commit` e `git -C <dir> commit` do comando, resolvem `git rev-parse --show-toplevel` do target, e procuram `.deepseek/reviews/` no repo TARGET — não no CWD do agente. Cross-repo work (CWD do agente ≠ repo do commit) passa a respeitar R11 sem workaround "cópia placeholder review".
- **Proposta G (diagnostic):** mensagens de bloqueio do hook incluem `git root: <repo>`, `searched: <path>` e `cwd: <path>` (este último apenas quando difere do git root). Operador/agente sabe imediatamente se erro é cross-repo, missing review, ou path-resolution.
- **Invariante D+E (regressão):** `tests/hardening-2026-05-19.tests.ps1` falha o build se:
  - `hooks.json` ganha entrada `PostToolUse` (qualquer matcher), ou
  - qualquer hook `PreToolUse` declara matcher `Edit|Write|MultiEdit|NotebookEdit`, ou
  - qualquer `.ps1`/`.sh`/`.cmd` em `scripts/hooks/skills/commands` contém `git checkout -b`/`git switch -c`/`git branch <novo>`.
- **`.percus-version`** atualizado: estava parado em `6.5.2` (não estava no loop de validação pre-push) → `6.7.2`.

**Decidido NÃO fazer agora:** skill `/percus-review:version` (bonus do doc 2026-05-19). Operador hoje lê `CANON_VERSION.md`; adicionar skill inflaria surface area sem incidente claro. Re-avaliar se houver terceira ocorrência de confusão de versão.

**Council consultado (3/3 Opção A):** DeepSeek + Llama + Cross-Claude concordaram com o escopo (F+G+invariante D/E, adiar skill version). Cross-Claude destacou: "F sem G deixa hook em modo fallback silencioso — viola R14 (observabilidade estruturada)". Por isso F e G entraram no mesmo bump.

---

## Changelog v6.7.1 — 2026-05-18

- **Fix marketplace.json duplicação:** `.claude-plugin/marketplace.json` (raiz, fonte única consumida pela UI) estava parado em `6.5.2` enquanto `plugin/.claude-plugin/marketplace.json` (duplicado órfão) era bumpado a cada release. Causa raiz de 3 incidentes recorrentes em v6.6.0/v6.6.1/v6.7.0.
- Deletado `plugin/.claude-plugin/marketplace.json`. Fonte única passa a ser raiz.
- **Pre-push hook (`tools/hooks/pre-push`):** bloqueia `git push` se `marketplace.json` vs `plugin/percus-review/plugin.json` divergem em versão, ou se duplicação ressurgir. Install via `tools/hooks/install.sh`.

---

## Changelog v6.7.0 — 2026-05-18

**Sprint 2 completo (sobre v6.7.0-alpha):**

- **Fact-check pipeline (F3 reformulado):** `scripts/fact-check.ps1`/.sh — etapa OBRIGATÓRIA pós-reviewer. Findings `[SEV: risco|bug]` passam por subagent Sonnet que lê arquivos citados. INFUNDADO filtrado do output principal; audit block preserva todos. Integrado em `percus-review-auto.ps1` (default). Opt-out via `--no-fact-check`.
- **Echo dedup (F5):** `scripts/dedup-findings.ps1`/.sh — agrupa findings por MD5(file_path + 100 chars). PR stacks com mesmo finding viram "1 unique, presente em N PRs" em vez de "N confirmações independentes".
- **Test suite regressão (F6):** `tests/hardening-2026-05-18.tests.ps1` — 11 testes estáticos que validam todas as defesas implementadas. 11/11 pass. Rode em CI ou pre-release.
- **Skill enforcement (F7):** `commands/council-consult.md` ganha seção "Pre-requisitos (enforcement v6.7.0+)" exigindo fact-check de findings críticos antes de escalar. Warning estruturado pro agente seguir.

**Sprint 1 (v6.7.0-alpha, 2026-05-18 — incluído no v6.7.0 final):**
- Router F1: sensitive_paths +5 padrões (alembic, internal, infra, config, services)
- Canon F4ab: R11 expansion + R20 nova ("decisões de conselho não autorizam ação externa pública")
- Hook F4c: external-action-guard.ps1 (PreToolUse, bloqueia gh pr comment/slack-cli/push sem PERCUS_EXTERNAL_OVERRIDE)
- Council F2: -CodeContextDir + premise_validity + premise_validity_consensus aggregator

**Smoke validations:**
- F2 (orchestrator code injection): ambos providers retornaram `premise_validity: invalid` em claim falso sobre outbox pattern. Comportamento que preveniria incidente 2026-05-18.
- F6 (hardening tests): 11/11 pass cobrindo todos os 4 cenários do reporter + 3 bonus.

---

## Changelog v6.7.0-alpha — 2026-05-18

**Anti-hallucination hardening Sprint 1** (pós-incidente Plexco Tasks):

- **Router (F1):** `sensitive_paths` expandido com `alembic/versions/`, `api/v\d+/internal`, `infra/*.yaml`, `(backend|app)/.*config.py`, `services/(auth|payment|notification|webhook)/`. PRs tocando esses paths agora rotam `decision=dual` automaticamente.
- **Canon (F4ab):** R11 ganha adendo "alegação técnica sobre função importada → ler implementação OU marcar 'não verificada'" + linha na matriz de roteamento. R20 nova: "decisões de conselho não autorizam ação externa pública" (PR comments, Slack, deploy, push) sem gate explícito do operador.
- **Hook (F4c):** `external-action-guard.ps1` PreToolUse bloqueia `gh pr comment`, `gh issue close`, `slack-cli`, `git push` sem `PERCUS_EXTERNAL_OVERRIDE=1`. Layer 1 enforcement runtime do R20.
- **Council (F2):** `council-orchestrator.ps1` ganha `-CodeContextDir <path>` + parser ```file:path```. Providers recebem código real + instrução pra reportar `premise_validity: ok|invalid|unverified` antes de opinar. Aggregator `premise_validity_consensus` no output JSON. Smoke validou: claim falso sobre outbox pattern → ambos providers retornaram `invalid`.

**Pendente v6.7.0 final (Sprint 2):**
- F3: fact-check pipeline (etapa obrigatória, INFUNDADO filtrado antes do consolidador)
- F5: echo dedup em PR stacks
- F6: test suite hardening-2026-05-18 (4 cenários do reporter)
- F7: skill `council-consult` enforcement

---

## Changelog v6.6.1 — 2026-05-18

- **Fix orchestrator integration:** `council-orchestrator.ps1`/.sh agora passa `-Mode $Mode` (não `-SystemPrompt`) ao invocar cross-claude wrapper. Bug v6.6.0: wrapper detectava `PSBoundParameters.ContainsKey('SystemPrompt')` = true e pulava load do `.md` enriquecido. F.1 cache estava ativo só em chamadas standalone, não via orchestrator.
- Validado: smoke via orchestrator confirma cache_read >= 1024 tok em consecutive calls.

---

## Changelog v6.6.0 — 2026-05-18

- **F.1 cache Anthropic ATIVO** para Sonnet 4.6 e Opus 4.7 (validado: 3142 tok read do cache em smoke E2E). Haiku 4.5 não cacheia (limitação Anthropic atual).
- SystemPrompts enriquecidos em `providers/system-prompt-{consult,review}.md` (~2400/~2800 tok cada, R1-R19 condensadas + antipadrões + padrões aprovados + exemplos calibrados).
- Wrapper `cross-claude.ps1`/.sh ganha `-Mode consult|review|pre-mortem`.
- `hooks/canon-version-check.ps1` warn pre-commit (não bloqueia) se SystemPrompt desatualizado vs canon.
- `scripts/smoke-cache-f1.ps1` valida cache via `cache_creation_input_tokens` + `cache_read_input_tokens`.
- Defensive guards: `$PSScriptRoot` null fallback, YAML strip regex EOF-safe, bash `--mode` validation (parity PS ValidateSet).

---

## Como cada projeto consumidor declara sua versão

Todo projeto Percus deve ter um arquivo `.percus-version` na raiz, com uma única linha contendo a versão do canon que adotou no último upgrade. Exemplo:

```bash
cat .percus-version
# 6.3.0
```

**Para que serve:**
- Operador sabe qual versão um projeto está rodando sem ler todo HANDOFF.
- Agente Claude, ao entrar no projeto, lê `.percus-version` e sabe quais regras valem (R1–R19 da v6.x, R14–R18 ainda não existem em v4.x, etc).
- Comando `UPGRADE_PARA_FASE6.md` (e futuros UPGRADE_*) atualiza esse arquivo ao concluir o upgrade — então um diff em git mostra exatamente quando o projeto migrou.
- `analyze-council-spend.py` e futuras ferramentas de catalog podem agregar projetos por versão.

---

## Versões do canon Percus (histórico)

| Versão | Marco | Data | Mudanças principais |
|---|---|---|---|
| **6.5.2** | Patch: UPGRADE_PARA_FASE6 e descriptions consistentes | 2026-05-17 | Header/instruções de `UPGRADE_PARA_FASE6.md` ainda mencionavam v6.4.0/v6.3.0 — migrados pra "versão canônica atual em CANON_VERSION.md" ou placeholder `vX.Y.Z`. `plugin.json` e `marketplace.json` descriptions alinhados com a versão real (estavam stuck em "Fase 6 v6.5.0" desde o bump pra v6.5.1, causando UI Manage Plugins mostrar versão antiga). |
| 6.5.1 | Patch: refs operacionais desatualizadas → `CANON_VERSION.md` | 2026-05-17 | Limpeza de 4 refs vagas de versão (pré-requisitos de comandos apontando pra versões intermediárias). Operacionais viraram "ver `${env:PERCUS_CANON_DIR}/CANON_VERSION.md`"; refs históricas ("feature introduzida em vN.N.N") mantidas intactas. |
| 6.5.0 | Canon portável | 2026-05-17 | `PERCUS_CANON_DIR` env var (User-scope) substitui hardcode `D:\Claud Automations\_Novo_Projeto` em 28 arquivos (comandos, templates, scripts, skills, hooks). `SETUP_NOVA_MAQUINA.md` (novo) automatiza bootstrap em máquina nova: git clone + env vars + verificação. Canon agora funciona de qualquer path absoluto — não mais dependência de estrutura `D:\Claud Automations\...` específica da máquina do operador principal. Resolve "outro computador não tem D:\Claud Automations\\_Novo_Projeto, todos os comandos quebram". |
| 6.4.0 | DX e versionamento | 2026-05-17 | `CANON_VERSION.md` canônico + `.percus-version` por projeto (declara versão adotada); protocolo de 1º turno no `CLAUDE.template`. `SKILLS_VS_COMMANDS.md` (novo doc) resolve confusão recorrente de agentes pedindo skills como slash commands. Seção "API keys do kit Percus" em `AMBIENTE_LOCAL_OPERADOR` (User-scope env vars eliminam `.env` recorrente em cada projeto novo). `SCOPE_COUNCIL` reescrito Fase 6 ($0.05 → $0.005 via `/council:pre-mortem` paralelo). Funções do orchestrator renomeadas pra approved PS verbs (`Measure-Tokens`, `Limit-Prompt`). |
| 6.3.0 | Eixo F entregue | 2026-05-17 | Truncation 8k orchestrator; model router automático Haiku/Sonnet/Opus por mode; wrapper Anthropic direto com cache_control; A/B router aprovado (-70% custo Cross-Claude consult); auditoria F.3 hooks zero-LLM + F.7 skill descriptions revisadas; baseline analyze-council-spend.py. |
| 6.2.0 | Eixo B Sprint 3 | 2026-05-16 | Skills tracking-audit (R2), delegate-impl (R13), security-audit (R14–R19). |
| 6.1.x | Eixo C | 2026-05-16 | Conselho 3-membros (DeepSeek + Groq-Llama + Cross-Claude); council-orchestrator paralelo; commands `/council:consult/pre-mortem/brainstorm/drift-detect`; hook `pre-plan-exit`. |
| 6.0.0 | Eixo B Sprint 2 | 2026-05-16 | 5 hooks pre-commit (pre-commit-check, mock-scan, auth-import, migration-check, types-check); 5 skills; on-stop auto-trigger catalog-publish. |
| 5.1.0 | Fase 5 v5.1 | 2026-05-03 | Auto-trigger review pelo agente via wrapper `percus-review-auto`. Git hook nativo Layer 2 anti-bypass. |
| 5.0.x | Fase 5 v5.0 | 2026-05-02 | Skills `feature-flow` + `close-milestone`. Hooks pre-commit defesa em profundidade. |
| 4.x | Fase 4 | 2026-04 | Review cross-provider sem Codex/OpenAI — DeepSeek + Cross-Claude via plugin `percus-review`. |
| 3.x | Fase 3 | 2026-04 | Harmonização do kit + tooling. |
| 2.x | Fase 2 | 2026-03 | DeepSeek implementador (R13) + design v0/shadcn (R10). |
| 1.x | Fase 1 (DEPRECATED) | 2026-03 | Codex como revisor cross-provider — descontinuado por custo. |

---

## Como saber se um projeto está na versão atual

Compare:

```bash
# Versão canônica
type "${env:PERCUS_CANON_DIR}\CANON_VERSION.md" | findstr "Versão canônica"

# Versão do projeto (na raiz do projeto-alvo)
type .percus-version
```

Se divergir → rode `comandos/UPGRADE_PARA_FASE6.md` (ou versão mais recente quando publicarmos Fase 7).

---

## Convenção de versionamento

Semver:
- **MAJOR** (`6.x.x` → `7.x.x`): nova Fase do canon. Migration runbook obrigatório. Mudanças breaking nas regras R*.
- **MINOR** (`6.3.x` → `6.4.x`): nova capacidade dentro da Fase (novo Eixo entregue, nova skill, novo hook). Compatível pra trás.
- **PATCH** (`6.3.0` → `6.3.1`): bugfix, doc fix, refactor sem mudança de comportamento. Skill descriptions ajustadas, audit fixes.

Tag no git do `huboperacional/percus-kit` sempre bate com `plugin.json` versão.
