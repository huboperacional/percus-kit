## Saída de `jq`/`python` no Windows vem com CRLF e o `\r` mata a regex em silêncio {#crlf-mata-regex-git-bash}

`tags: crlf, \r, carriage return, jq, python, git-bash, windows, regex nao casa, padrao morre calado, command substitution, tr -d, msys, mapfile, @tsv, ultimo campo, jq -j, jq -b, --binary, jq.exe nativo, dispatcher, paridade sh`

**Sintoma:** um padrão lido de arquivo/JSON simplesmente **não casa**, sem erro nenhum. O mesmo
padrão, colado à mão no shell, casa. No caso real, cada projeto declarava seus caminhos sensíveis
num JSON e o router lia, aceitava e ignorava — silenciosamente.

**Causa raiz:** `jq` e `python` no Windows escrevem **CRLF**. `$(...)` remove só o `\n` final, então
cada linha chega com `\r` colado no fim. Uma regex terminada em `$` vira `...$\r` e não casa com
nada. Um path comparado por igualdade também nunca bate. Some ao fato de que ler o mesmo dado por
`sed`/`grep` costuma **mascarar** o problema (`[[:space:]]` inclui `\r`), e o bug fica restrito a um
dos caminhos de leitura.

**Solução:** todo dado que vem de processo externo passa por `tr -d '\r'` antes de virar
regex/comparação. E teste a **pipeline de verdade** (o script rodando com o arquivo real), não a
lógica de matching isolada: em teste unitário as strings vêm limpas e o bug não aparece.

**Ref:** `CANON_VERSION.md` v6.31.0 (achado enquanto se testava o próprio fix, 2026-07-27).

---

**Reincidência em 2026-09-13 (`percus-dispatch-{pre,post}.sh`, a paridade `.sh` dos dispatchers), com
três facetas que o texto acima não tinha.**

1. **O `\r` cai no ÚLTIMO CAMPO, e isso disfarça.** `jq -r '... | @tsv'` lido por `mapfile -t` deixou
   o `\r` colado no último campo de cada linha. O nome do check vinha no primeiro campo, limpo, então
   o tripwire "check registrado mas AUSENTE do disco" seguia funcionando e o dispatcher **parecia
   saudável**. O gatilho vinha no último campo como `zeta\r`, que nunca casa: `checks rodados: 0 de 5`,
   exit 0, nenhum aviso. A guarda inteira ficou desligada com a mesma cara de "nenhum gatilho casou".
   🔑 **O que discrimina:** um check **sem** gatilho também não rodar. Esse tem de rodar sempre, e só
   não roda se o campo vazio virou `\r`.
2. **`-j` não escapa do problema, e `-b` conserta.** Medido: `jq -n -j '"a\nb"'` sai `a\r\nb`, porque
   o modo texto do `jq.exe` nativo troca `\n` por `\r\n` **dentro do valor**, e não só no fim da linha.
   `jq -b -j '"a\nb"'` sai `a\nb`. Para leitura por linha, `tr -d '\r'` basta. Para texto que vai ser
   **repassado** (o stdout de um hook, que o harness injeta no agente), use `-b`, senão o conteúdo
   chega diferente do que o check escreveu.
3. **Por que reincidiu.** Este verbete existe desde 2026-07-27, e o `.sh` foi escrito sem o grep. A
   regra "consultar antes de investigar" vale também **antes de escrever** código que atravessa a
   mesma fronteira. Quem pegou foi o teste de paridade que roda o `.sh` com o `jq.exe` real ao lado do
   `.cmd`: `plugin/percus-review/tests/dispatch-pre-paridade-sh.tests.ps1`. Teste da lógica isolada,
   com strings limpas, teria passado, exatamente como o parágrafo "Solução" já avisava.
