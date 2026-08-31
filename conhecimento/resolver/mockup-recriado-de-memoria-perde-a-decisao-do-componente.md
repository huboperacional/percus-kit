## Mockup recriado de memória perde a DECISÃO que o componente carrega — e o cliente revisa o seu erro em vez do produto {#mockup-recriado-de-memoria-perde-a-decisao-do-componente}

`tags: design, mockup, devolutiva, design system, token, primitivo, vocabulario, placeholder, review do operador, retrabalho, R10`

**Sintoma:** o cliente abre a devolutiva de design e pede coisas que **o produto já faz**:
"põe uma bordinha aqui", "troca esse texto", "essa cor não é a nossa". Cada pedido parece uma
melhoria; na verdade é o mockup divergindo de algo que já existe, já foi decidido e às vezes
foi decidido **por ele mesmo**, semanas antes.

**Causa raiz:** o artboard foi desenhado a partir da memória do que o componente parece, em
vez de copiado do componente real. O que se perde nessa recriação nunca é a forma grosseira —
é a **decisão**: o token que existe só para aquele caso, o vocabulário padronizado, a regra de
contraste medida. Coisas que não se deduzem olhando, porque foram tomadas contra a aparência
óbvia.

**Caso medido (Empresa Milionária, 2026-08-30):** devolutiva de 9 artboards, três achados
seguidos, todos da mesma causa:

1. **Cor.** O mockup usou um verde `#2F6F4E` que **não é cor de identidade nenhuma** — as sete
   reais estão no código com contraste anotado (`#2F6B34` é o verde, CR 5,52). Pego pela
   segunda leitura, não pelo cliente.
2. **Borda.** O trilho de abas foi desenhado sem contorno. O cliente pediu "uma bordinha um
   pouco mais forte" — e o primitivo real já tem `border-borderStrong`, com um comentário que
   diz exatamente o que ele descreveu ("*sem ele o segmento ativo boia*") e registra a decisão
   como **pedido explícito dele, de 11 dias antes** ("não enfraqueça").
3. **Vocabulário.** O mockup inventou o placeholder "Não informar"; o produto usa "Selecione"
   como default de componente, com decisão escrita ao lado.

**O custo real não é o retrabalho** (três linhas de CSS). É que **o cliente gastou a revisão
dele conferindo se o mockup copiou certo**, em vez de decidir o que só ele pode decidir — no
caso, o conteúdo de dois templates de nicho que dependiam do conhecimento do ramo dele.

**A regra prática, antes de desenhar qualquer tela de um produto que já existe:**

- localize o **design system** (tokens, paleta) e os **primitivos** (o arquivo de componentes)
  e leia os valores de lá, seguindo o token até o valor resolvido;
- para cada componente que o mockup vai mostrar, ache o **componente real** e copie a anatomia
  — não o "jeitão";
- **os comentários no código do design system são a parte que mais importa**: é onde mora o
  *porquê* de um valor não ser o óbvio. Um token com comentário longo é um valor que já foi
  discutido e perdido uma vez;
- vocabulário de interface (placeholder, rótulo, texto de estado vazio) é design system também
  — invente-o e o mockup passa a ensinar uma língua que o produto não fala.

⚠️ **Sinal de que já aconteceu:** o cliente pede algo que você lembra de ter visto no código.
Antes de aplicar, `grep` o comportamento pedido — se o produto já faz, a tarefa muda de
natureza (é conserto do mockup, escopo de uma linha) e a resposta a ele muda também: ele
precisa saber que o produto está certo, senão fica achando que o defeito está no que os
usuários usam.

**Corolário para a devolutiva seguinte:** quando os três primeiros achados forem desta classe,
pare de corrigir um a um e faça **uma varredura do canvas inteiro contra o produto** —
tokens, primitivos e vocabulário — antes de aplicar qualquer pedido novo. O quarto achado já
existe; ele só não foi visto ainda.

Relacionado: [[a-sabotagem-prova-o-que-voce-imaginou]],
[[guarda-por-nome-e-cega-ao-serializer-generico]].
