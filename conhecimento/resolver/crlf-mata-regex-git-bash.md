## Saída de `jq`/`python` no Windows vem com CRLF e o `\r` mata a regex em silêncio {#crlf-mata-regex-git-bash}

`tags: crlf, \r, carriage return, jq, python, git-bash, windows, regex nao casa, padrao morre calado, command substitution, tr -d, msys`

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
