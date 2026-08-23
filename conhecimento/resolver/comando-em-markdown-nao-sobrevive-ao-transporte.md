## Comando escrito em markdown não sobrevive ao transporte — e falha calado {#comando-em-markdown-nao-sobrevive-ao-transporte}

`tags: shell, markdown, plano, runbook, copy-paste, byte de controle, 0x01, SOH, sed backreference, PowerShell, cat colapsa, $(cat), verde falso, exit 0 silencioso, heredoc, escape, vps_exec`

**Contexto:** um plano ou runbook guarda comandos de shell dentro de blocos de código markdown, para
a próxima sessão copiar e rodar. O comando atravessa camadas — o gerador que escreveu o `.md`, o
markdown, o copy-paste, o shell local, o SSH, o shell remoto — e **cada camada pode comer ou
transformar um caractere sem avisar**.

**Dois modos medidos no mesmo dia (2026-08-23), os dois produzindo `exit 0` sem tocar o alvo:**

### 1. `\1` de `sed` virou byte de controle `0x01`

O prefixo de conexão do plano tinha `sed -n 's#…:\([^@]*\)@.*#\1#p'` para extrair a senha. Escrito
por um script Python cujo `"\1"` (fora de raw string, e depois de o heredoc do bash comer uma barra)
é o **escape octal do caractere SOH**. O `.md` ficou com `#^A#p` — **invisível na tela**, sobrevive
a copy-paste, e teria quebrado 17 comandos com `password authentication failed`: um erro que parece
de rede ou de credencial, não de texto.

Detecção: `grep -c $'\x01' arquivo` · `cat -A` · `od -c`. Nenhuma revisão visual pega.

⚠️ Consertar com `perl -i -pe 's/\x01/\\1/g'` **piora**: no lado de substituição do perl, `\1` é
backreference para um grupo que não existe ⇒ vira **string vazia**. O `\1` some de vez.

### 2. `$(cat prefixo.sh)` colapsa em UMA linha no PowerShell

A correção "shell mora em arquivo, não em markdown" é certa — mas o arquivo era colado com
`$(cat ops/prefixo.sh)`. Em **bash** isso preserva as quebras de linha; em **PowerShell** o `cat`
devolve `string[]` e a interpolação junta tudo **com espaço**. Com um único `#` de comentário no
arquivo, o comando remoto inteiro vira **um comentário só** ⇒ `sh` não executa nada ⇒ **`exit 0`,
zero output, gate verde sem ter tocado o banco.**

**Correção:** o arquivo de prefixo não tem comentário nenhum, e **toda linha termina em `;`**. Assim
funciona idêntico colapsado ou não — e os dois modos são testados:

```bash
tr '\n' ' ' < ops/prefixo.sh > /tmp/colapsado.sh   # simula o PowerShell
# rodar as duas versões e conferir que produzem o MESMO resultado
```

O porquê (que morava nos comentários) migra para o documento que referencia o arquivo, com um ⛔
explícito: *não acrescente comentário aqui*.

**Blindagens que valem para qualquer comando versionado:**

- Prefixo/trecho de shell em **arquivo versionado**, protegido por `.gitattributes text eol=lf`.
- **Guarda que falha alto** dentro do próprio trecho, para o caso de a resolução falhar:
  `if [ -z "$PG" ] || [ -z "$SENHA" ]; then echo "prefixo: nao resolvi"; exit 1; fi;`
  — sem ela, variável vazia segue adiante e o erro chega deformado.
- Varredura de bytes de controle antes de commitar documento que carrega comando:
  `grep -c $'\x01'` (e, em geral, `[[:cntrl:]]` fora de `\n\t\r`).
- Nunca montar o comando com backslash através de heredoc + Python: use `chr(92)` ou raw string, e
  **confira o byte depois de escrever**.

**Regra geral:** comando que vai ser copiado é **dado**, e dado que atravessa camadas precisa de
verificação na ponta — a mesma exigência de
[mutação que não casa](mutacao-que-nao-casa-finge-que-o-gate-nao-reprova.md), aplicada ao texto do
comando em vez de ao defeito injetado.
