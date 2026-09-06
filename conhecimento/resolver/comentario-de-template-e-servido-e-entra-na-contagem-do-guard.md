## Comentário de template chega no visitante — e entra na contagem do guard que varre o HTML {#comentario-de-template-e-servido-e-entra-na-contagem-do-guard}

`tags: template, jinja, html, css, guard, teste, vazamento, contagem, comentario, publico`

### Contexto

Página pública servida por template (Jinja/ERB/Blade/qualquer um) com um bloco `<style>` ou
`<!-- -->` inline. O comentário parece "documentação interna" — o autor escreve nele o racional
de engenharia, a decisão de time, o número do golden, o incidente que motivou a peça.

Dois sintomas, aparentemente sem relação:

1. Um guard de vazamento que proíbe termo interno na página começa a falhar **sem que a copy
   tenha mudado**.
2. Uma asserção de contagem passa a medir **um a mais** do que existe na tela — `count("<tag>")`
   devolve 11 onde há 10 elementos.

### Causa raiz

**O comentário é servido.** O bloco `<style>` vai inteiro no HTML que sai pro navegador,
comentário incluso, visível em "ver código-fonte". Logo:

- o texto escrito PRA MIM é medido pelos guards que varrem o HTML **renderizado**;
- escrever o nome de uma tag entre sinais de menor/maior dentro do comentário faz essa string
  entrar na contagem de qualquer teste que procure por ela.

Aconteceu **três vezes na mesma frente** (tiatendo, `/roadmap`, 2026-09-05): o comentário disse
"o mockup **aprovado**" e derrubou o guard do valor de um campo interno; reescrito, disse
"**operador**" e derrubou o guard de processo interno; e ao documentar um accordion escrevendo
`summary` entre sinais de menor/maior, quebrou a contagem de fases.

O agravante: depois disso o autor afirmou **"vazamento = 0"** tendo medido só UMA palavra. A
review independente baixou a página ao vivo e mostrou o comentário narrando decisão de time e um
incidente.

### Solução

1. **Racional de engenharia mora no arquivo que NÃO é servido** — o módulo de conteúdo em
   Python/Ruby, o docstring, o ADR. No template, no máximo um ponteiro de duas linhas.
2. **O guard mede a CLASSE, não palavras.** Lista de termos proibidos mede o vocabulário de
   ONTEM: o comentário novo sempre usa outras palavras e passa. A régua que funciona é
   estrutural — *"nenhum comentário com mais de N caracteres no CSS servido"*:

   ```python
   estilo = html[html.index("<style>"):html.index("</style>")]
   longos = [c for c in re.findall(r"/\*.*?\*/", estilo, flags=re.S) if len(c) > 400]
   assert not longos
   ```
3. **Contra-prove.** Rode o guard contra a versão ANTERIOR do arquivo. Se ele não reprovar o
   defeito que você acabou de consertar, o guard é decoração.
4. **Escreva o par positivo** (um `<style>` sintético com comentário gigante). Sem ele, a
   asserção negativa passa por medir o vazio — e continuaria passando se o regex parasse de casar.
5. Guard de contagem que varre HTML: prefira ancorar num atributo do elemento
   (`class="x-title"`) em vez do nome cru da tag, que aparece também em prosa.

**Ref:** tiatendo `execution/dashboard/templates/roadmap.html`,
`tests/dashboard/test_roadmapRender.py::test_bloco_de_estilo_nao_narra_processo_interno`,
ADR-0019 (2026-09-05).

**Relacionado:** [comentário não é gate](comentario-nao-e-gate.md) ·
[guard de texto acha a menção antes do uso](guard-de-texto-acha-a-mencao-antes-do-uso.md) ·
[assert que casa CSS não prova markup](assert-casa-css-nao-prova-markup.md)
