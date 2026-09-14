## Escape unicode escrito pelo agente num arquivo chega ao disco como o CARACTERE, e não como texto {#escape-unicode-escrito-pelo-agente-chega-ao-disco-como-o-caractere}

`tags: write, edit, ferramenta do agente, escape, escape unicode, U+001F, byte de controle, 0x1F, binary data, file, fonte corrompido, teste verde, separador invisivel, jq, bash, heredoc`

**Sintoma:** um script escrito pelo agente funciona, os testes passam, e `file` classifica o arquivo
como `... (binary data)`. Aberto no editor ou no diff, um trecho parece errado sem estar: um
separador que parece vazio.

**Caso medido (2026-09-13, `percus-dispatch-pre.sh`).** O programa `jq` usava como separador o escape
unicode de U+001F, escrito como barra-u seguida de `001f`. No disco, a linha ficou com o **byte 0x1F
cru** dentro das aspas. Na mesma escrita, as outras sequências de barra (`\x1f` dentro de `$'...'`,
`\r`, `\n`, `\\A`, `\(`) ficaram **como texto**. Só a forma barra-u foi convertida. Em outra chamada,
um heredoc do Bash com a barra dobrada antes do `u` chegou com a barra simples. O mecanismo exato não
foi isolado; o que está medido é o efeito.

**A classe é mais velha e mais larga que o U+001F.** A varredura de bytes desta mesma sessão achou,
já commitado, um **byte 0x08 (backspace)** num changelog antigo do `CANON_VERSION.md`, escrito por
outra sessão: a prosa citava o escape barra-b (fronteira de palavra de regex, "que ERE não tem") e ele
chegou ao disco como o caractere. Outro escape, outro arquivo, outra sessão, o mesmo efeito, e ele
sobreviveu a vários commits e reviews porque é invisível. Foi trocado pelo texto em 2026-09-13.

**Por que nenhum teste pega:** o `jq` aceita o caractere cru dentro da string, então o comportamento é
**idêntico**. Um teste de comportamento não tem como distinguir as duas grafias. Só olhando os bytes.

**Por que importa mesmo sem bug:**
- **O byte é invisível.** No diff do review, a linha parece `join("")`, um separador vazio que um
  revisor apontaria como defeito (ou, pior, "consertaria").
- **Byte de controle em arquivo de lote é defeito de verdade:** o `cmd.exe` lê por offset de byte, e é
  a classe de [[cmd-com-byte-nao-ascii-desalinha-o-cmd-exe-e-come-o-inicio-das-linhas]].
- **Em prosa (`.md`), escreva `U+001F`,** e não a sequência de escape. Citar o escape corre o mesmo
  risco de virar o caractere.

**Como pegar e consertar:**
1. Depois de escrever arquivo com escapes, **varra os bytes**: qualquer byte abaixo de `0x20` que não
   seja TAB, LF ou CR (e, em arquivo que deveria ser ASCII, acima de `0x7E`). `file` dizendo
   "binary data" num fonte já é o alarme.
2. Conserte **por script** que troca bytes (Python com `bytes.replace`), e não pela ferramenta de
   edição, que pode repetir a conversão ao receber o mesmo texto.
3. Varra de novo depois do conserto. O script que consertou este caso também foi escrito pelo
   agente, e a verificação final foi o que confirmou a grafia certa no disco.

**Recorrência pela ferramenta de edição, e o caminho inverso (LiliCalc, 2026-09-14).** Um regex de
TypeScript que normaliza os espaços do `Intl` (U+00A0 e U+202F) passou pelas duas direções:

- **Reescrever o arquivo inteiro a partir do que a leitura mostrou trocou os dois caracteres por
  espaço comum.** A leitura exibe U+00A0 e U+202F como espaço; quem reescreve copiando o que viu grava
  espaço. O regex virou "troca espaço por espaço" — defeito de comportamento, não só de grafia.
- **O conserto com a forma barra-u, pela ferramenta de edição, chegou ao disco como os caracteres
  crus** — o efeito deste verbete, agora também no Edit.

A varredura de bytes pegou as duas, antes de o teste rodar. O conserto que ficou foi um PowerShell que
monta a barra com `[char]92` e troca a string no arquivo, seguido de nova varredura. Regra prática:
**não reescreva inteiro um arquivo que tem caractere invisível** — edite o trecho, e varra os bytes
depois.

**Relacionado:** [[crlf-mata-regex-git-bash]] (o outro caractere invisível da mesma tarefa, vindo do
`jq.exe`) · [[teste-de-hook-no-windows-mede-o-ambiente-do-runner-e-nao-o-do-harness]].
