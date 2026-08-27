## Scanner que compara contra o valor de PROVENANCE reprova correção legítima {#scanner-contra-provenance-nao-contra-saida-final}

`tags: i18n, auditoria, falso-positivo, provenance, inventario, bundle, string matching, tradução, acentuação`

**Contexto:** pipeline de extração de i18n com um inventário versionado
(JSON) que registra, por chave, o texto de ORIGEM (`pt`/`fragmentos`) tal
como foi lido do código-fonte no momento da curadoria. Um script de auditoria
roda em dois modos: `--somente-fonte` (grep no código-fonte, contra o texto
de origem) e completo (grep também no BUNDLE compilado, pra provar que a
tradução chegou ao artefato).

**O achado:** depois de fechar um gate de 28 "ausentes da fonte" (0 restantes,
verificado), rodar o modo completo revelou 14 novas "ausentes do bundle" —
aparentemente uma regressão nova. Investigação (grep byte-a-byte direto em
`dist/assets/*.js`) mostrou que as 14 traduções estavam TODAS presentes,
corretas, nos 3 idiomas. O motivo: o pipeline **corrige de propósito**
acentuação/gramática ao gravar a tradução final (`"Investor"→"Investidor"`,
`"Distribuicao"→"Distribuição"`) — prática já estabelecida e desejável — mas
o campo `pt` do inventário continua com o texto de ORIGEM não corrigido. O
scanner de bundle faz `grep` do valor do inventário contra o bundle; como o
bundle tem o valor CORRIGIDO, a busca falha, e o script reporta "ausente"
para uma tradução que na verdade está perfeita.

**Por que isso não aparece no modo `--somente-fonte`:** esse modo busca o
texto de origem no CÓDIGO-FONTE (onde ainda não foi corrigido, porque a
correção só acontece no arquivo de tradução final) — então bate. É só o
cruzamento "texto de origem" × "artefato já traduzido/corrigido" que
diverge.

**A armadilha:** o output do scanner (`ausentes do bundle: 14`) tem o mesmo
formato de um defeito real de tradução faltando — não distingue "não
traduzido" de "traduzido diferente do que o inventário registra". Sem
verificar manualmente o bundle, um agente reverteria as correções (voltando
pra "Investor"/"Distribuicao" sem acento) só pra fazer o número bater — uma
regressão real pra satisfazer um falso-positivo de tooling.

**Como aplicar**
1. Quando um scanner de auditoria compara contra um campo de PROVENANCE
   (texto tal como foi originalmente lido/curado), qualquer correção
   legítima feita DEPOIS da curadoria (acento, gramática, terminologia)
   vai gerar divergência — isso é esperado, não é reincidência do defeito
   original.
2. Antes de "corrigir" pra fazer o número do scanner bater, verifique
   manualmente se o valor final está correto no artefato real (bundle,
   banco, o que for). Se está, o scanner é que está desatualizado — não
   force uma reversão.
3. Documente a limitação no lugar onde o número aparece (changelog, PLANO,
   README do inventário) — sem isso, a mesma investigação se repete do
   zero na próxima vez que alguém rodar o scanner e ver o número > 0.
4. O consertar de verdade (scanner comparar contra o valor FINAL, não
   contra provenance) é trabalho de tooling separado — não force essa
   correção dentro do escopo de uma fase de conteúdo se não for
   estritamente necessário.
