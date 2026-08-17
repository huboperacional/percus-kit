## Perna bash do `mock-scan` estava morta duas vezes: `grep -P` sem locale e regex cortada no `|` errado {#mock-scan-perna-bash-morta-por-locale-e-split}

`tags: mock-scan, hook, R3, grep -P, LC_ALL, locale, guarda morta, 2>/dev/null, exit 2, parameter expansion, %%|*, portugues, TODO, falso positivo, paridade de pernas`

**Sintoma A (o que aparece):** commit legítimo barrado porque a palavra portuguesa **"todo"**,
escrita em caixa alta por ênfase, casa com o marcador `TODO`. O canon manda comentar em português,
então isso não é acidente raro — aconteceu **duas vezes na mesma sessão** em 2026-08-17, com
`"cada imagem e TODO chunk de JS"`.

**Sintoma B (o que NÃO aparece, e é pior):** na perna `.sh`, **nada nunca é detectado**.

**Causa raiz A — o parser corta a regex no primeiro `|`:**

```bash
patterns=( '\b(?-i:TODO|FIXME|XXX|HACK)\b[: ]|TODO/FIXME/XXX/HACK pendente' )
re="${p%%|*}"     # -> \b(?-i:TODO      <- grupo DESBALANCEADO
why="${p##*|}"    # -> TODO/FIXME/XXX/HACK pendente   (este está certo)
```

`${p%%|*}` remove o maior sufixo a partir do **primeiro** `|`. O formato `'regex|motivo'` só funciona
enquanto a regex não contiver `|` — e essa entrada continha três. `grep` sai com **2** (erro de
sintaxe), o `2>/dev/null` engole a mensagem, e `exit != 0` é lido como "não casou".

**Causa raiz B — `grep -P` recusa rodar sem locale UTF-8:**

```
grep: -P supports only unibyte and UTF-8 locales
```

Medido numa máquina com `LANG=` vazio (Git Bash no Windows). Isso derruba **todos** os padrões da
perna bash, não só o do marcador: lorem ipsum, `dummy_`, URL de localhost, tudo. A perna inteira
respondia verde sem checar nada.

🔑 **As duas causas se escondem pelo mesmo mecanismo:** `2>/dev/null` combinado com tratar
`exit != 0` como "não casou". **`grep` devolve 1 para "não achei" e 2 para "não consegui procurar"** —
juntar os dois transforma falha de ferramenta em aprovação silenciosa.

**Solução (cinco partes, e três delas só apareceram depois da primeira tentativa):**

1. **Um padrão por marcador, sem `|` dentro da regex** — respeita o parser em vez de brigar com ele.

2. 🔴 **SONDAR o MOTOR, não escolher um locale.** Três voltas até chegar aqui, e cada uma foi
   necessária:
   - v1 usava `LC_ALL=C.UTF-8`. O review apontou que `C.UTF-8` **não existe no macOS nem em vários
     containers** e sugeriu `C`, já que os padrões são ASCII.
   - v2 usou `C`. **Medido: `LC_ALL=C` NÃO resolve no Git Bash do Windows** — continua `rc=2`. Cada
     candidato conserta uma plataforma e mata a outra.
   - v3 sondava locale. O review apontou o furo maior: **o `grep` do macOS é BSD e não tem `-P` de
     jeito nenhum**, então sondar só locale faria o hook **bloquear todo commit num Mac** — pior que
     o defeito original.

   A versão que sobrevive sonda um **motor PCRE**: `grep -P` com o primeiro locale que funcionar, ou
   `perl` (presente por padrão no macOS e em quase todo Unix). Sem nenhum dos dois, fail-closed.

   ⚠️ **E o fallback de perl tem uma armadilha própria:** interpolar a regex pelo shell dentro de
   `/.../` quebra em qualquer padrão que contenha `/` — o de URL de localhost tem três, e o perl
   morre com `syntax error`, que vira "não consegui procurar" e bloqueia tudo. A regex tem de entrar
   por **variável de ambiente**:
   ```bash
   PERCUS_RE="$re" perl -ne 'exit($_ =~ /(?i)$ENV{PERCUS_RE}/ ? 0 : 1)'
   ```
   🔑 **Isso só apareceu porque o teste exercita os DOIS motores.** O motor perl nunca roda nesta
   máquina — sem testá-lo explicitamente, ele iria para o macOS sem jamais ter sido executado uma vez.
   Fallback não exercitado é fallback não existente.

3. 🔴 **`rc=2` tem de BARRAR, não avisar.** A primeira tentativa trocou o silêncio por um aviso no
   stderr e seguia com `continue` — o review chamou isso do que era: **o mesmo fail-open de antes,
   só que barulhento**. Guarda que não consegue procurar não sabe se há mock, e não saber nunca pode
   virar liberação. Agora bloqueia com mensagem própria, distinta da de "achei mock".

4. 🔴 **`set -e` transforma a correção em no-op se a captura for uma atribuição pura.** Com
   `set -eo pipefail` no topo, `saida=$(... | grep -q ...)` **encerra o script** quando o grep sai 1 —
   e sair 1 é o caso comum ("não casou"). Ou seja, o hook morreria na primeira linha que não casasse.
   Provado com um script de 4 linhas. A forma que sobrevive:
   ```bash
   grep_err=$(echo "$line" | LC_ALL="$PERCUS_GREP_LOCALE" grep -qiP "$re" 2>&1) && rc=0 || rc=$?
   ```
   O `if ... grep ...; then` original não tinha esse problema porque comando dentro de condição é
   isento do `set -e` — trocar a estrutura reintroduziu o risco que ela escondia.

5. **`TODO` passa a exigir `:` ou `(`** (`\b(?-i:TODO)\s*[:(]`); `FIXME|XXX|HACK` seguem com
   `\b...\b[: ]` porque não são palavras em português. Custo aceito e declarado:
   `// TODO consertar` sem dois-pontos deixa de ser pego — a forma canônica é `TODO:` / `TODO(dono):`.

⚠️ **O teste que eu escrevi para provar o conserto caiu na MESMA armadilha.** Ele extraía os padrões
do hook com `grep -oP` — sem `LC_ALL` — carregou **zero padrões**, e todos os casos negativos
"passaram" por vacuidade. Só os positivos denunciaram. **Todo teste de padrão precisa de uma guarda
de contagem mínima** (`if [[ ${#patterns[@]} -lt 5 ]]; then abortar; fi`), senão ele vira exatamente
o tipo de verde vazio que estava tentando expor. Mesma família de
[[reference_review_limpo_pode_ser_vacuidade]].

**Como provar que está vivo (positivo E negativo, ATRAVÉS do hook — nunca o script direto):**
stage um arquivo com `// TODO: x` → tem que **bloquear**; troque por
`// cada imagem e TODO chunk` → tem que **passar**. Se outro hook bloquear na segunda, leia o NOME
do hook na mensagem: bloqueio de outro gate não é bloqueio do `mock-scan`.

✅ **A correção vale na hora, sem republicar o plugin:** o `.cmd` é trampolim para o kit. Medido — a
mensagem mudou de "TODO/FIXME/XXX/HACK pendente" para "marcador TODO pendente" no disparo seguinte.

**Ref:** medido em 2026-08-17 no repo `website-autoworxnj`, canon 6.36.6. As duas pernas
(`.ps1` e `.sh`) foram alinhadas em comportamento e mensagem — divergência entre pernas do mesmo
hook já custou caro antes (ver o conserto da 6.36.3, que consertou três arquivos e esqueceu o quarto).
