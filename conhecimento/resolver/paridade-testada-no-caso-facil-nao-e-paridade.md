## Paridade testada só no caso fácil não é paridade — o fixture escolhe o que o teste consegue ver {#paridade-testada-no-caso-facil-nao-e-paridade}

`tags: teste, paridade, ps1, sh, pester, fixture, bash, powershell, arredondamento, banker rounding, review, R11, cross-provider, buraco calado, context-budget-guard`

**Sintoma:** existe um teste de paridade, ele passa, e as duas implementações divergem mesmo assim.
Ninguém desconfia — o teste tem o nome certo, roda os dois runtimes de verdade, e está verde.

**O caso medido (2026-09-12, `context-budget-guard`).** Um teste comparava `.ps1` e `.sh` e passava.
Sete rodadas de review cross-provider depois, **cinco** divergências reais tinham sobrevivido a
ele — cada uma escondida por uma escolha diferente do fixture:

| O fixture usava | E por isso não via |
|---|---|
| o modelo default (`claude-opus-5`) | o `sed` do `.sh` que extraía o campo `model` estava **corrompido** e devolvia vazio — nunca exercitado |
| janela redonda (`200000`) | `[int]($x)` no PowerShell é **banker's rounding**, não truncamento: divergia do bash só em valor com fração |
| só o `.ps1` (apesar do nome "nos dois runtimes") | tudo do outro lado |
| só a mensagem do **agente** | a mensagem do **operador**, que repetia um valor que a outra acabara de negar |
| uma env por vez | a combinação de duas envs, onde os dois ramos se contradiziam |

**A causa comum:** um teste de paridade prova que as implementações concordam **no caminho que o
fixture exercita**. Se o fixture usa o valor redondo, o campo default, o runtime conveniente e uma
variável por vez, ele prova concordância no lugar onde ninguém diverge. O nome do teste promete
"paridade"; o corpo entrega "paridade no caso fácil", e a diferença não aparece em lugar nenhum.

**Discriminante — como saber se o seu teste de paridade é de verdade.** Para cada valor do fixture,
pergunte *"que bug este valor torna invisível?"*:

- **Número redondo** esconde toda divergência de arredondamento. Use um que tenha fração no ponto
  onde o código divide: `161500 / 200000 = 80,75%` separa `Round` (81) de truncamento (80).
- **Valor default de campo** esconde o parser daquele campo. Se o código lê `model`, teste com um
  `model` que **importa**, não com o que vem no molde.
- **Um runtime** não prova nada sobre o outro. Se o nome diz "os dois", o corpo roda os dois.
- **Um caminho de saída** esconde os outros. Se o código emite duas mensagens, compare as duas.
- **Uma variável de ambiente por vez** esconde a interação. Os ramos `A` e `B` podem estar certos
  sozinhos e se contradizer juntos.

**Compare o artefato inteiro, não um campo escolhido.** O teste original extraía só o `~Nk` da
mensagem com regex e comparava. Trocar isso por comparar a **string inteira** das duas
implementações pegou, de uma vez, divergências de percentual, de texto e de ramo. Campo escolhido a
dedo é o fixture fácil outra vez, agora do lado da asserção.

**Quem pegou:** o review cross-provider, em sete rodadas — e cada rodada achou coisa que a anterior
não tinha achado **porque a anterior tinha mudado o código**. Vale registrar: consertar cria bug
novo, e três dos quinze findings eram regressões introduzidas pelos consertos das rodadas
anteriores. Uma delas era **pior que o bug original** (silenciava um alarme legítimo). Review não é
carimbo de saída; enquanto o diff muda, ele volta a valer.

Ver [[cadeia-de-hooks-cobra-420ms-por-hook-mesmo-em-no-op]] para a outra metade desta sessão, e
[[detector-que-casa-identificador-por-texto]] para a família "o detector mede o rótulo, não a coisa".
