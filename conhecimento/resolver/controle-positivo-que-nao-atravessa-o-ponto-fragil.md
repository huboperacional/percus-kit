## Controle positivo que não atravessa o ponto frágil confirma o experimento errado {#controle-positivo-que-nao-atravessa-o-ponto-fragil}

`tags: controle positivo, prova de ausencia, zero como prova, grep, rg, ripgrep, escape, shell, aspas duplas, aspas simples, ancora $, regex, falso negativo, busca impossivel, probe cego, rigor aparente, R23`

**Sintoma.** Você faz tudo certo: mede uma **ausência**, desconfia do zero, e roda um **controle positivo** na mesma chamada para provar que o instrumento funciona. O controle passa. O zero vira prova. E o zero era falso — o instrumento estava cego exatamente na parte que o controle não tocou.

**Causa raiz.** O controle positivo prova o que ele exercita, e só isso. Se ele exercita uma parte do instrumento e o alvo depende de **outra**, ele mede um caminho que não estava em risco. Passa por coincidência estrutural, não por saúde do experimento.

O caso medido, e ele é fácil de repetir:

```bash
rg -n "R\$ ?[0-9]" service.py   # -> exit 1, ZERO linhas   <- lido como "não há preço digitado"
rg -c "async def"  service.py   # -> 84                    <- controle positivo: PASSA
```

O `84` prova que o `rg` está instalado, que roda, que o caminho existe e que o arquivo é legível. Não prova **nada** sobre o que quebrou: em **aspas duplas o shell come a barra invertida antes de o `rg` ver o padrão**, então o `rg` recebe `R$ ?[0-9]`. O `$` no meio de um regex é **âncora de fim de linha** — o padrão pede "um `R`, depois o fim da linha, depois um espaço". Não pode casar nada. O `exit 1` não era ausência: era **busca impossível**.

Com aspas simples o `rg` recebe `R\$ ?[0-9]`, com `$` literal, e acha **10** ocorrências.

🔑 **O controle e o alvo tinham padrões DIFERENTES, e a diferença era o defeito.** `async def` não tem `\$`, então atravessava o shell intacto. O controle foi construído para ser fácil de acertar — que é precisamente como se constrói um controle que não discrimina.

**Isto é emenda a [[zero-so-vale-como-prova-com-controle-positivo]], não substituto.** Aquele verbete manda *"rode o MESMO probe, sem alterações, no controle"*, e está certo. O furo é que na prática ninguém roda o mesmo probe: roda a **mesma ferramenta com outro padrão** — porque o padrão do alvo, por definição, não acha nada no controle. E é na troca do padrão que a parte frágil desaparece.

**Solução: o controle tem de manter intacta a parte que pode quebrar.** Três formas, da mais barata à mais forte:

1. **Par de variantes do próprio probe.** Rode o comando nas duas formas que diferem só no ponto suspeito. Se derem o **mesmo** número, o escape não sobreviveu:
   ```bash
   rg -c 'R\$ ?[0-9]' arquivo   # -> 10
   rg -c "R\$ ?[0-9]" arquivo   # -> 0    divergiu: o shell comeu a barra
   ```
2. **Veja o que a ferramenta recebeu**, em vez de deduzir: `printf '[%s]\n' "R\$ ?[0-9]"` imprime `[R$ ?[0-9]]` e encerra a discussão. Vale para qualquer camada que reescreve argumento (shell, `Makefile`, YAML de CI, JSON de hook).
3. **Controle positivo com o padrão do ALVO**, plantado de propósito: `echo 'R$ 19,90' | rg -c 'R\$ ?[0-9]'` tem de dar `1`. Este é o único que exercita o padrão inteiro.

**Como reconhecer na hora.** Pergunte do controle: *"se o defeito que eu temo existisse, este controle falharia?"* Se a resposta é não, ele não é controle — é decoração cara, e pior que nenhum, porque **entrega a sensação de rigor sem o rigor** e encerra a investigação.

**Onde mais morde.** Qualquer instrumento cuja expressão passa por uma camada que a reescreve: `$` e `!` em aspas duplas; `\d` que o `grep` BRE não conhece; glob expandido pelo shell antes de chegar ao programa; regex em YAML de CI onde `\` é escape do YAML; padrão vindo de variável de ambiente. Em todos, um controle "simples" — sem metacaractere — passa alegremente enquanto o padrão real está morto.

⚠️ **Assimetria que vale lembrar:** o mesmo defeito de guarda por texto erra nos **dois** sentidos. Aqui a busca não pode casar nada e **some com o defeito** (falso negativo). No irmão [[trava-que-varre-texto-le-comentario-como-codigo]] a busca casa o comentário que **explica** o conserto e **inventa** defeito (falso positivo). O desempate é o mesmo nos dois: **ler as ocorrências, nunca contar.**

**Ref:** 2026-09-07, Empresa Milionária — P28. Uma sessão auditou o tracking do preço nas mensagens automáticas, concluiu certo (nenhum preço de plano digitado no `service.py`) e registrou como prova um `rg` que não podia casar nada, com o `84 async def` de controle. A conclusão sobreviveu ao fact-check; a prova não — e a receita *"confirme em 30 segundos"* do documento ensinava o falso negativo a quem a seguisse. Achado e concessão entre duas sessões da mesma árvore. Irmão de [[a-guarda-que-nao-pode-falhar-mora-no-instrumento]] e de [[o-par-positivo-tambem-passa-por-coincidencia]].
