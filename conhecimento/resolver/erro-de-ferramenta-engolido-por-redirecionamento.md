## Erro de ferramenta engolido por `2>/dev/null` deixa a guarda INERTE, e o exit code continua 0 {#erro-de-ferramenta-engolido-por-redirecionamento}

`tags: gate, shell, stderr, 2>/dev/null, grep, awk, sed, exit code enganoso, guarda inerte, escape comido, continuacao de linha, silencio, script que roda e nao faz nada`

**Sintoma:** um bloco de gate/script "roda" — sai **0**, não imprime nada, os testes passam — e a
verificação que ele deveria fazer simplesmente **não acontece**. Nada indica isso; o único jeito de
notar é auditar o stderr, que está redirecionado para o nada.

**Causa raiz:** o comando interno recebeu um argumento quebrado (caminho, flag, continuação de linha)
e reclamou no stderr. Como muitos blocos silenciam stderr para não poluir a saída com ruído legítimo
(permissão negada, diretório inexistente), o erro real vai junto. O comando "funciona" devolvendo
resultado vazio, e resultado vazio é indistinguível de "nada a acusar".

**O caso (percus-kit, 2026-08-18): três vezes na mesma sessão, a mesma classe.** Editando o gate por
substituição de string, um escape foi consumido numa camada intermediária e virou literal:

```sh
# o que eu escrevi (intencao)          # o que foi pro disco
--exclude-dir='node_modules' \         --exclude-dir='node_modules' \n
                                       #                             ^^ backslash + letra 'n'
```

O `grep` recebeu `n` como **nome de arquivo**, errou, e o erro morreu no `2>/dev/null`. As exclusões
que vinham depois deixaram de valer. O gate seguiu saindo 0. Em outra ocasião foi um `\r` que quebrou
a continuação de linha e passou `r` como operando.

🔑 **Exit code não pega esta classe, e teste de comportamento também não** — o teste afere "o gate
barra o que deve barrar", e ele barra: as OUTRAS checagens continuam funcionando. O que morreu foi
uma exclusão, e exclusão que não vale só aparece quando alguém tropeça nela.

**Solução:**
1. **Teste o STDERR, não só o exit code.** Rode a ferramenta e asserte que nenhuma linha casa
   `^(grep|awk|sed|find|xargs|sort):` — prefixo de ferramenta, não texto do seu script (as violações
   legítimas também saem no stderr e não podem ser confundidas com defeito):
   ```
   saida | Where-Object { $_ -match '^\s*(grep|awk|sed|find|xargs):' } | Should -BeNullOrEmpty
   ```
2. **Redirecione com precisão, não em bloco.** `2>/dev/null` no comando inteiro esconde o que você
   não previu. Se o ruído esperado é "arquivo não existe", filtre por ele.
3. ⚠️ **Não edite código-fonte por substituição de string atravessando camadas.** O escape é comido
   de forma imprevisível entre a linguagem que gera, o heredoc do shell e o destino — foi a causa das
   três ocorrências. Use ferramenta de edição que escreve o texto literal, ou escreva o comando numa
   linha só.
4. **Depois de editar um script, leia a linha alterada com `cat -A`** (ou equivalente): `\` no fim é
   continuação; `\n`/`\r` no meio é bug.

**Relacionado:** [guarda-de-link-escrita-da-forma-que-voce-acabou-de-usar](guarda-de-link-escrita-da-forma-que-voce-acabou-de-usar.md)
— lá a guarda cobre pouco; aqui ela não roda, e nos dois casos o sintoma é o mesmo: verde que não
significa nada.

**Ref:** percus-kit 6.38.0, 2026-08-18, bloco 2c do `v2/gates/percus-gate.sh`. Achado pelo review R11
na sétima rodada, depois de duas ocorrências anteriores da mesma classe passarem despercebidas.
