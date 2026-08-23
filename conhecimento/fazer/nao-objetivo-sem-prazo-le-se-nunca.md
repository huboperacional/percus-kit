## Não-objetivo sem prazo lê-se "nunca", e alguém vai citá-lo para vetar o próprio roadmap {#nao-objetivo-sem-prazo-le-se-nunca}

`tags: spec, requisito, nao-objetivo, escopo, roadmap, versao, ambiguidade, emenda, contradicao aparente, posicionamento`

**Quando:** a spec tem uma seção de não-objetivos escrita como lista corrida, e **alguns itens
trazem prazo** (*"emissão de nota fiscal na v1 e v2"*, *"integração contábil antes da v4"*)
enquanto **outros não** (*"estoque"*, *"CRM e vendas"*).

**O defeito:** os dois tipos se leem igual. Um item sem qualificador é indistinguível de um item
com prazo omitido — e o leitor resolve a ambiguidade sozinho, em silêncio, quase sempre para o
lado mais forte: **"nunca"**.

**O custo é concreto e já foi pago.** Um agente leu *"estoque"* como não-objetivo permanente e
afirmou **duas vezes**, num documento de roadmap, que o produto contradizia o próprio
posicionamento — chegando a propor um ADR para resolver uma contradição que **não existia**. O
documento de precificação dizia, três arquivos adiante, *"coisas que a EM não faz **e só pretende
fazer a partir da v3**"*, e o menu do produto já anunciava os dois itens como v3 para quem usa.

**Passos:**
1. **Toda entrada da lista declara até quando vale.** Sem exceção, mesmo quando o prazo parecer
   óbvio para quem escreve — quem lê daqui a seis meses não tem o contexto de hoje.
2. **Antes de declarar contradição entre dois documentos do próprio repositório, leia a fonte
   inteira.** A frase que parece contradizer costuma ter a ressalva na mesma linha.
3. **Ao emendar, preserve o texto original riscado** e escreva a emenda embaixo, com **data e
   razão**. Emenda que apaga o que dizia antes esconde por que mudou, e a próxima pessoa refaz a
   discussão do zero.
4. **Registre o custo dentro da emenda**, não só na mensagem de commit. Quem lê a spec não lê o
   `git log`, e é a spec que instrui a próxima ação.
5. **Não emende item cuja decisão ainda não tem ADR.** Deixe-o intacto com uma nota e o gatilho
   ("quando o ADR-XXXX existir, este item recebe o mesmo tratamento") — antecipar a decisão pelo
   documento errado é o defeito espelhado.

**Armadilhas:**
- ⚠️ **Uma entrada pode ser duas coisas coladas.** *"Partida dobrada e plano de contas contábil"*
  virou base numa metade (o livro derivado, que ninguém digita) e continuou não-objetivo na outra
  (o plano de contas **na interface**). Emendar a entrada inteira teria contrariado o ADR que a
  descartou; separar preservou o argumento original.
- ⚠️ **Não-objetivo não é o único lugar com esse defeito.** Qualquer requisito na voz passiva sofre
  do mesmo mal — *"documentos devem ser guardados por 5 anos"* não diz **por quem**, e essa
  ambiguidade custou uma rodada inteira de conselho no mesmo repositório, na mesma semana.

**Relacionado:** [Spec que só fotografa passa verde na página 404](../resolver/spec-que-so-fotografa-passa-verde-na-pagina-404.md)

**Ref:** Empresa Milionária, 2026-08-23 — §9 da spec de design; a leitura errada de "estoque" e
"CRM e vendas" produziu uma contradição inexistente num documento de roadmap, e o mesmo arquivo já
carregava o FR-042 emendado dias antes pelo defeito irmão (voz passiva sem sujeito).
