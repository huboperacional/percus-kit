## `401` com chave IDÊNTICA entre `.env` e variável de ambiente não é o padrão de env-var-velha — pode ser a chave morta de verdade {#401-identico-nao-e-env-stale-pode-ser-chave-morta}

`tags: credencial, 401, cross-claude, council-orchestrator, anthropic, diagnostico errado, R23`

**Sintoma:** o `council-orchestrator.ps1` devolve `401 — API key is invalid` na perna Cross-Claude,
em rodadas repetidas (medido 3× na mesma sessão). O reflexo natural, dado o verbete
[[401-em-wrapper-que-herda-env-nao-prova-nada-sobre-a-chave]], é suspeitar de variável de ambiente
herdada de um processo antigo.

**Diferença que importa:** naquele verbete a causa é o wrapper ler um valor VELHO enquanto o
`.env`/painel já tem o valor NOVO — dois valores diferentes, o processo preso no errado. Aqui é
outra coisa: `[Environment]::GetEnvironmentVariable("ANTHROPIC_API_KEY","User")` e
`$env:ANTHROPIC_API_KEY` do shell atual batem **byte-a-byte** com o `.env` do projeto — **um valor
só**, o mesmo em todo lugar, e a Anthropic rejeita esse valor mesmo assim. Não há valor "bom"
escondido atrás de um valor "velho" — a chave está genuinamente inválida/revogada do lado do
provider.

**Como distinguir os dois casos rápido:** comparar os dois valores (env de usuário vs `.env`) ANTES
de reemitir credencial ou investigar o wrapper.
- Valores DIFERENTES → é o padrão do verbete irmão (env stale), a correção é `export`/re-source no
  processo certo.
- Valores IGUAIS e ainda assim `401` → não adianta reemitir/sincronizar nada; ou a chave está morta
  no provider (rotação/revogação fora desta sessão), ou é falha temporária do lado deles. Não é
  ação de agente resolver — reportar o sintoma e seguir com contorno.

**Contorno pra não perder a 3ª perspectiva do conselho:** o JSON do orchestrator carrega o
`system_prompt` usado (campo próprio na resposta). Dispatch um subagente `general-purpose` com esse
MESMO prompt, sem mostrar as respostas dos outros providers (preserva independência), pra completar
a rodada de pre-mortem/review sem a perna Cross-Claude. Custa 1 chamada de Agent extra, evita tratar
`2 de 3 pernas` como consenso completo.

Relacionado: [[401-em-wrapper-que-herda-env-nao-prova-nada-sobre-a-chave]] (o caso irmão, valores
DIFERENTES).
