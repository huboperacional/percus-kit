## Varredura de marca com `rg` não acha logo do produto de origem: texto não lê binário {#varredura-de-texto-nao-le-binario}

`tags: fork, produto derivado, vazamento de marca, identidade, logo, asset herdado, png, binario, varredura, rg, grep, falso verde, marca dagua, watermark, auditoria de asset, data de modificacao`

**Contexto:** produto nascido por **fork** de outro. A identidade foi trocada, e a varredura de
marca — `rg` sobre `src/` e `public/` inteiros, padrão com e sem acento — deu verde três vezes
seguidas, em sessões diferentes. A logo do produto **de origem** continuou renderizando numa
página pública indexada, como marca d'água a 7% de opacidade, por sete dias.

**Causa raiz:** o nome do produto antigo estava **desenhado nos pixels** de um PNG
(`public/logos/logo-white.png`), não escrito em lugar nenhum do código. Nenhuma varredura de
texto casaria com ele — não é limite do padrão de busca, é limite da **classe** de busca. O
arquivo era referenciado por um caminho neutro (`logo-white.png`), então nem o nome do arquivo
denunciava.

**Por que ninguém viu antes:** o `alt` era `""` (correto para elemento decorativo, e por isso
invisível a auditoria de acessibilidade e a qualquer varredura de string no DOM); a opacidade de
7% faz a marca sumir em revisão rápida; e um **comentário no código descrevia o arquivo errado** —
dizia que era "a silhueta do ícone", o que fez três leitores humanos pularem a linha. Quem pegou
foi um **screenshot do operador**, pedindo outra coisa.

**Diagnóstico — asset herdado se audita pelo ARQUIVO, não pelo texto:**
1. **Data de modificação denuncia.** `ls -la` na pasta de assets: os arquivos do fork têm a data do
   fork, os do redesign têm a data do redesign. Um PNG de 11/08 no meio de arquivos de 15/08 é o
   suspeito, sem precisar abrir nada.
2. **Proporção declarada contra a real.** `width`/`height` no código que não batem com o header do
   PNG indica arquivo trocado sem revisar a linha. Foi o caso: `300x90` (3,33) declarado para um
   arquivo de proporção 0,92.
3. **Abrir o arquivo.** Toda ferramenta de agente moderna renderiza PNG. É o passo que fecha, e é
   barato.
4. **Comentário que descreve asset é dado não confiável** — verifique contra o arquivo antes de
   usá-lo para descartar um suspeito.

**Solução:** apagar o asset no mesmo commit da troca — enquanto o arquivo existir, ele volta na
próxima tela que precisar de uma logo. E corrigir o comentário mentiroso junto, porque ele é parte
da causa.

⚠️ **A lição generaliza para além de logo:** qualquer identidade dentro de binário — favicon,
og-image, PDF de contrato, áudio de espera, sprite, vídeo — é invisível à varredura de texto. Ao
declarar "varri e não achei", declare também **a classe do que foi varrido**: "varri o texto"
não é "varri o repositório".

**Relacionado:** [Marcar uma entidade como "fora do padrão": filtre os EMISSORES, não só os leitores](marca-varre-emissores-e-leitores.md)

**Ref:** Empresa Milionária, 2026-08-18 — logo da Família Milionária no CTA final da home, no ar
desde o fork de 11/08, sobrevivendo às varreduras de 17/08 e 18/08.
