## Mesma regra escrita em dois interpretadores (.ps1 + .sh) diverge calada {#regra-duplicada-ps1-sh}

`tags: duplicacao, ps1, sh, bash, powershell, paridade, gate, router, lista hardcoded, drift entre implementacoes, case-insensitive, fonte unica, teste que raspa fonte`

**Sintoma:** o gate protege quando roda por um caminho e não protege pelo outro — ou pior, ninguém
nota, porque cada máquina/agente usa só um dos dois. Nenhum erro aparece.

**Causa raiz:** a mesma lista/regra existe em duas implementações (array no `.ps1`, cadeia
`[[ =~ ]]` no `.sh`) e nada força as duas a concordarem. No caso real eram **três** cópias: os
testes ainda **raspavam a regex do fonte `.ps1`** com `[regex]::Matches(...)` — então (a) o `.sh`
nunca era testado e (b) o padrão que não casava com a regex de raspagem (`'^\.env'`, que não começa
com `(`) ficou anos sem cobertura. Divergência achada: `-match` do PowerShell é **case-insensitive**
por padrão e `[[ =~ ]]` do bash é **case-sensitive** — `backend/Auth/` escalava num e não no outro.

**Solução:** a regra vira **dado**, num arquivo lido pelos dois (e pelos testes). Restrinja a
sintaxe ao subconjunto comum aos dois motores (`[0-9]`, não `\d`; nada de `(?...)`) e tenha **teste
de paridade**: mesma entrada nos dois executáveis, mesma saída. Sem o teste de paridade, a fonte
única volta a divergir na primeira "correção rápida" de um lado só. Teste que lê o **fonte** em vez
do **dado** é pior que não ter teste: quando a lista sai do fonte, ele passa a extrair lista vazia e
o teste negativo ("não é sensível") passa por vacuidade.

**Ref:** `CANON_VERSION.md` v6.31.0 (router de pasta sensível); report "Melhoria na VPS" 2026-07-27.

⚠️ **A classe é MAIOR que `.ps1` vs `.sh`, e reincidiu três versões seguidas.** Vale para **quaisquer
duas implementações da mesma regra**, mesmo em linguagens e papéis diferentes — em 2026-08-16 foram
um **gate em bash** e um **mesclador em PowerShell** que precisavam concordar sobre "o que é um
verbete válido". Oito rodadas de review acharam 25 defeitos, e **17 deles eram os dois discordando**,
em oito dimensões que ninguém lista de antemão: bloco de código, blockquote, CRLF, BOM, caixa
alta/baixa, profundidade de pasta, qual `{#...}` da linha conta como âncora, e título vazio.

**O que torna a classe traiçoeira:** cada lado tem teste, cada teste passa, e **nenhum dos dois pode
detectar a divergência** — ela não é observável de dentro de um lado só. Só aparece quando alguém
compara as duas cópias, ou quando produção pega um caso que atravessa as duas.

**A regra prática, que vale mais que o conselho de "fonte única":** fonte única nem sempre é possível
(um gate `sh` não importa função PowerShell). Quando não for, **o teste tem de comparar as duas
cópias**, não testar cada uma. Dois testes independentes, um por lado, ficam verdes lado a lado
enquanto as implementações divergem — foi exatamente o que aconteceu com a tabela de modelos
duplicada (6.36.3) e com o `temperature` em três arquivos (6.36.4). Exemplos de guarda que funciona:
`cross-claude-mode-load.tests.ps1` (extrai a tabela dos dois orquestradores e exige igualdade) e
`provider-limites.tests.ps1` (paridade de teto e timeout entre `.ps1` e `.sh`).
