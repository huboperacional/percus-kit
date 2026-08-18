## Fatiar arquivo CRLF: a quebra de linha mente em TRÊS camadas, e todas em silêncio {#crlf-mente-em-tres-camadas-ao-fatiar-arquivo}

`tags: CRLF, LF, fim de linha, universal newlines, python newline, git show, autocrlf, migracao de arquivo, byte-identico, comparacao, windows, git bash, conversao silenciosa`

**Sintoma:** ao dividir/converter um arquivo grande, a verificação "o conteúdo novo é idêntico ao
antigo" falha de um jeito absurdo — ou passa quando não devia. Os números não fecham: o script diz
que fatiou 398 blocos e a conferência acha 0; ou o diff mostra o arquivo inteiro alterado quando você
tocou em 3 linhas.

**Causa raiz: a quebra de linha é traduzida em três fronteiras diferentes, nenhuma delas avisa.**

| # | Fronteira | O que acontece | Como fica silencioso |
|---|---|---|---|
| 1 | **Leitura na linguagem** | `open(p, encoding='utf-8')` no Python usa *universal newlines*: `\r\n` vira `\n` na string | Gravar depois converte o arquivo INTEIRO sem aviso; o diff explode |
| 2 | **`git show`** | devolve o conteúdo como o git **armazena** (LF), não como está na árvore (CRLF, por `autocrlf`) | Comparar `git show` com o arquivo do disco **nunca** bate byte a byte |
| 3 | **Escape em edição indireta** | um `\r` escrito por engano no meio de uma linha vira **carriage return de verdade** e parte o caminho ao meio | `conhecimento\resolver` → `conhecimentoesolver`, e o erro só aparece em runtime |

**O caso (percus-kit, 2026-08-18):** fatiar um monólito de 1 MB em 398 arquivos. (1) A primeira
leitura traduziu CRLF→LF e `split('\r\n')` devolveu **uma única linha** — 0 verbetes encontrados.
(2) Conferir contra `git show HEAD:` deu **0 esperados / 398 em disco**, porque o git entrega LF.
(3) Um caminho de teste ganhou um CR literal e o `New-Item` falhou com "sintaxe do nome do arquivo
incorreta".

**Solução:**
1. **Ler e gravar com `newline=''`** (Python) ou equivalente que **desliga** a tradução. O que está na
   string é o que vai pro disco.
2. **Para comparar através da fronteira do git, compare LINHA A LINHA, não byte a byte.** Byte-idêntico
   entre `git show` e árvore é impossível por definição quando há `autocrlf` — exigir isso é escrever
   um critério que nunca passa. Normalize os dois lados (`rstrip('\r')`) e compare listas de linhas:
   continua sendo prova literal de que nenhum conteúdo mudou.
3. **Não edite arquivo por substituição de string atravessando camadas** (linguagem → heredoc →
   shell): o escape é comido de forma imprevisível. Use ferramenta que escreve texto literal.
4. **Depois de editar, leia a linha com `cat -A`.** `$` no fim é LF; `^M$` é CRLF; `\r` ou `\n` no
   meio do texto é bug.
5. **Meça a quebra antes de assumir:** `d.count(b'\r\n')` vs `d.count(b'\n')` diz qual arquivo você
   tem, e vale 5 segundos.

⚠️ **O separador entre blocos também mente.** Ao fatiar, é tentador supor que os blocos são separados
por um padrão fixo. Medido no caso real: **6 formas distintas** (320× `---` entre linhas vazias, 59×
só linha vazia, 10× nada). Fatie por "do início de um bloco até o início do próximo" e remova só a
cauda — nunca dependa do separador ser uniforme.

**Ref:** percus-kit 6.38.0, 2026-08-18. Migração de `COMO_RESOLVER.md` para um-arquivo-por-verbete;
13.551 linhas conferidas linha a linha contra o commit, zero divergente.
