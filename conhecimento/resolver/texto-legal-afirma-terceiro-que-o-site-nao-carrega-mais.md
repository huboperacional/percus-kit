## Texto legal afirma um terceiro que o site não carrega mais — e ninguém revisa política depois do deploy {#texto-legal-afirma-terceiro-que-o-site-nao-carrega-mais}

`tags: politica de privacidade, texto legal, cookies, terceiros embutidos, youtube, iframe, afirmacao de fato, drift de documentacao, white-label, atribuicao de operador, GDPR, LGPD`

**Sintoma:** nenhum. É o ponto. A política de privacidade continua no ar, bem escrita, e descreve um site que **deixou de existir** — porque a implementação mudou e o texto legal não é lido por nenhum teste, nenhum gate e nenhum usuário até alguém precisar dele.

**Duas formas do mesmo defeito, ambas medidas em 2026-08-19 num site de cliente:**

1. **Terceiro que sumiu.** O texto listava *"YouTube, que reproduz os nossos vídeos"* entre os serviços que carregam e gravam cookie. Três dias antes, os vídeos tinham virado arquivos próprios (`videoSrc`); o único `youtube.com` restante era o link social do rodapé — **link não monta player nem grava cookie**. Medido no site vivo: **zero iframes de YouTube em 4 páginas**.
2. **Operador atribuído errado.** O texto dizia que o formulário roda no GoHighLevel *"(o domínio deles é `ads4pros.com`)"*. `ads4pros.com` é o domínio **da agência**, um white-label que aponta para o GHL — não é domínio do GoHighLevel. Numa política de privacidade, isso informa ao visitante a entidade errada como destino dos dados dele.

🔑 **Por que essa classe escapa de tudo:** teste de render compara marcação, não veracidade; review de diff olha o que mudou, e aqui o texto **não mudou** — mudou o mundo em volta; e o gate de mock/`[5-T]` pergunta "funciona?", não "é verdade?". Texto legal é o único lugar do produto que faz **afirmação de fato sobre terceiros**, e é o único que ninguém re-mede.

**Como achar (barato, e é medição, não leitura):**

```bash
# o site realmente embute o que a política diz embutir?
curl -s https://SEU.SITE/ | grep -oE "youtube\.com/embed|youtube-nocookie|player\.vimeo|iframe[^>]*maps"
# atenção: link para o canal NÃO é player. Separe href de iframe/script.
```

**Solução — derivar do dado, e tornar a flag OBRIGATÓRIA:**

```ts
export interface LegalCompany {
  /** OBRIGATORIO de propósito. Flag opcional muda em SILÊNCIO o que a política
   *  pública afirma, e qualquer default estaria errado para metade dos sites. */
  hasYouTubeEmbed: boolean;
}
// no call site:
hasYouTubeEmbed: siteEmbutePlayerYouTube(data),
```

⚠️ **Opcional com default é a armadilha específica aqui.** `hasYouTubeEmbed?: boolean` parece cortês e faz o texto omitir o YouTube em todo chamador que esquecer de passar — inclusive nos sites que ainda o embutem. Obrigatória, o compilador cobra a decisão de quem tem o dado.

⚠️ **A contagem escrita à mão é a mesma classe.** O texto abria com *"Três serviços carregam dentro deste site…"* e listava três. Quando a lista virou dois, a frase continuou dizendo três. Monte a frase a partir da lista — e faça a **concordância** derivar do mesmo array, senão a correção acerta a abertura e deixa o fecho no plural (aconteceu, e foi pego no review seguinte).

Relacionado: [comentario-afirma-garantia-que-o-codigo-nao-entrega](comentario-afirma-garantia-que-o-codigo-nao-entrega.md) · [regra-escrita-em-n-lugares-e-enforcada-em-nenhum](regra-escrita-em-n-lugares-e-enforcada-em-nenhum.md)
