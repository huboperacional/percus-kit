## Teste que prova que N cópias CONCORDAM nunca prova que o valor ANDOU {#concordancia-nao-prova-avanco}

tags: versionamento, bump esquecido, drift, dado denormalizado, copia sincronizada, teste de consistencia, gatilho ausente, alinhamento, single source, R25, CANON_VERSION, plugin.json, semver, suite verde e mentira

**Contexto:** um valor precisa aparecer em N lugares (versão em 4 arquivos, preço no pedido e no
item, status no cabeçalho e na linha, feature flag no back e no front). Alguém percebe o risco de
drift e escreve a suíte que compara os N — e ela fica verde para sempre.

**O que o teste NÃO cobre:** a suíte afere **concordância**, e o defeito real costuma ser
**estagnação**. `6.35.0` nos quatro arquivos, com um template novo dentro do mesmo commit, **passa
nos seis testes e mente**: os arquivos concordam perfeitamente entre si e todos discordam da
realidade. Nenhum teste de igualdade entre cópias pega isso, porque não existe segunda opinião no
sistema — todas as cópias vieram da mesma decisão errada de não bumpar.

**Como reconhecer na sua suíte:** todos os testes do arquivo têm a forma `A.campo == B.campo`. Se
não existe nenhum que compare o valor com algo **externo** (o remoto, o relógio, o conteúdo que
mudou), o que você tem é um detector de drift, não um detector de esquecimento.

**Solução — o gatilho, não mais uma comparação interna.** A pergunta certa não é "os N concordam?"
mas "esse valor tinha obrigação de mudar?". A âncora externa que responde isso costuma ser barata:
o estado já publicado.

```sh
v_publicada=$(git show origin/main:CANON_VERSION.md | extrai_versao)
v_local=$(git show :CANON_VERSION.md | extrai_versao)   # do INDICE, ver verbete irmao
[ -z "$v_local" ] && barra "arquivo de versao fora do indice"   # falha != "pule a checagem"
# ha conteudo relevante staged e a versao nao avancou sobre a publicada -> barra
```

**Limitação assumida:** `origin/main` é a ref de *remote-tracking* **local** — um hook de
pre-commit não roda `git fetch` (rede dentro de hook é lento e quebra offline), então ela pode estar
velha. Se outra pessoa publicou uma versão à frente, o gate compara com a antiga e libera. O dano é
contido porque o `git push` recusa o non-fast-forward depois, mas **o gate sozinho não substitui
estar em dia com o remoto**. Aceitar isso é melhor que colocar rede no caminho do commit.

**Três armadilhas ao escrever o gatilho, todas medidas na mesma sessão:**

1. **Comparar com "mudou neste commit"** obriga bump a cada commit da mesma versão. Gate que
   atrapalha vira gate escapado (ver `#gate-escapado-em-massa-e-regex-errado`). Compare com o
   **publicado**, não com o commit anterior.
2. **Testar só igualdade** (`local == publicada`) deixa passar o repo **atrasado** em relação ao
   remoto, que também está gravando conteúdo novo numa versão já publicada. Exija **avanço**.
3. **Ancorar o gatilho na presença do arquivo local** (`[ -f VERSAO ]`) dá duas portas grátis pra
   desligar tudo: tirar do índice, ou apagar do disco. Ancore no **remoto** — quem decide se este
   repo é o canon não é o disco de quem está gravando.

**Ref:** percus-kit v6.36.0, 2026-08-13. Os 6 testes de `version-alignment.tests.ps1` estavam
verdes havia meses enquanto a versão não subia junto com o conteúdo. As três armadilhas acima
saíram de rodadas sucessivas de review cross-provider (R11) sobre o próprio gate — nenhuma tinha
aparecido na primeira versão que eu dei por pronta.

Relacionado: [[#gate-le-working-tree-nao-o-indice]] (a outra metade do mesmo gate).
