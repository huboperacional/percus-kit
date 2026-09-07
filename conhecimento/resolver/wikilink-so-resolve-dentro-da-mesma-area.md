## `[[wikilink]]` entre áreas (`fazer/`↔`resolver/`) é estruturalmente impossível de resolver — mensagem do gate mente sobre o motivo {#wikilink-so-resolve-dentro-da-mesma-area}

`tags: gate, percus-gate.sh, conhecimento, wikilink, ancora, fazer, resolver, area, slug, link morto`

**Sintoma:** um verbete em `conhecimento/fazer/` linka um de `conhecimento/resolver/` (ou
vice-versa) via `[[slug]]`, e o gate acusa:

```
link para '[[alvo]]' nao resolve num arquivo existente (link morto nasce calado)
```

O arquivo **existe**. A mensagem manda procurar um arquivo que não existe, quando o problema
real é outro: o slug existe, só não onde o gate procurou.

**Causa raiz (medido em `v2/gates/percus-gate.sh` ~linha 315):** a resolução do alvo de
`[[slug]]` monta o path relativo ao diretório do **arquivo de origem**, não busca nas áreas
conhecidas:

```awk
d = FILENAME; sub(/\/[^\/]*$/, "", d)
print FILENAME "\t" d "/" alvo ".md" "\t[[" alvo "]]"
```

Se `FILENAME` é `conhecimento/fazer/X.md`, o alvo testado é sempre `conhecimento/fazer/<slug>.md`
— nunca `conhecimento/resolver/<slug>.md`, mesmo que seja lá que o slug realmente viva. Cross-área
é impossível de resolver por construção, não por bug pontual.

**Evidência de que já mordeu mais de uma vez:** `achatar-a-base-antes-da-cadeia-de-delta-build-estourar-125-camadas.md`
(em `fazer/`) linkando `[[docker-build-em-cima-de-imagem-delta-bate-max-depth]]` (que vive em
`resolver/`) bate exatamente neste padrão — achado independentemente por uma segunda sessão
(`empresa-milionaria-c1`, 2026-09-07) no mesmo dia que o achado original.

**Contorno enquanto não for decidido resolver ou não (2026-09-07, decisão do operador
pendente):** cite por caminho relativo, não por wikilink, quando o alvo está em área diferente:

```diff
- Ver [[docker-build-em-cima-de-imagem-delta-bate-max-depth]].
+ Ver [docker-build-em-cima-de-imagem-delta-bate-max-depth](../resolver/docker-build-em-cima-de-imagem-delta-bate-max-depth.md).
```

Isso passa no gate (esse ramo do awk só existe pra `[[..]]`, não pra link markdown por caminho) e
resolve certo em qualquer visualizador.

**Duas correções possíveis, nenhuma aplicada ainda:** (a) o gate busca o slug nas áreas
conhecidas antes de acusar link morto, resolvendo cross-área de verdade; (b) a mensagem passa a
dizer *"existe em `<área>`; wikilink só resolve dentro da mesma área — cite por caminho"* em vez
de "link morto", honesta sobre a causa mesmo sem resolver o caso. Fica para quem decidir a
arquitetura do gate — este verbete documenta o diagnóstico pra não repetir a investigação, não a
decisão.

**Princípio geral:** uma mensagem de erro que diz "X não existe" quando na verdade "X existe,
mas eu não sei procurar lá" está mentindo sobre a causa — e manda quem lê investigar o lugar
errado. Vale a pena, ao escrever guarda de validação de referência cruzada, testar o caso onde o
alvo existe **fora do escopo de busca**, não só "existe" vs "não existe" dentro dele.
