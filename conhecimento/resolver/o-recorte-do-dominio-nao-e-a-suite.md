## O recorte do domínio não é "a suíte", e a diferença aparece no deploy {#o-recorte-do-dominio-nao-e-a-suite}

`tags: suite completa, pytest, pre-deploy, gate, guarda de identidade, vazamento de marca, multi-sessao, branch compartilhada, tests/pj, falso verde, R11, deploy`

**Contexto:** projeto com o domínio novo isolado numa pasta de testes própria (`tests/pj/`) e o resto
da suíte herdado de um produto de origem. Rodar o recorte é rápido (~4 min) e a suíte inteira é lenta
(~30 min), então o hábito vira rodar o recorte e chamar o resultado de "a suíte" — inclusive no
relatório ao operador.

**O que aconteceu (2026-08-23):** três sessões trabalharam na mesma branch ao longo do dia. Cada uma
rodou `tests/pj`, viu verde (894 passed) e reportou "suíte verde". Antes de um deploy, a suíte
**completa** foi rodada pela primeira vez no dia: **3508 passed, 2 failed**.

As duas falhas eram as **guardas de vazamento de marca** — as que existem justamente porque o produto
já subiu uma vez exibindo o nome do produto de origem numa tela pública. Elas moram em
`tests/test_identidade_projeto.py`, **fora** do recorte do domínio. As duas violações entraram no
mesmo dia, de **duas sessões diferentes**, e nenhuma das duas viu.

**Causa raiz:** o recorte do domínio contém os testes que a feature nova escreve. As guardas
transversais — identidade/marca, licença, largura de coluna, contrato de migration, invariantes de
schema — moram fora dele por definição: elas varrem **o repositório inteiro**, então não pertencem a
nenhuma pasta de feature. Quem só roda o próprio recorte fica cego exatamente para as guardas que
protegem o produto como um todo.

**O agravante do multi-sessão:** o vazamento que você publica pode não ser seu. Com várias sessões
commitando na mesma branch, rodar só o próprio recorte significa que **cada uma valida o próprio
diff e ninguém valida o acúmulo**. As duas violações aqui eram comentários que nomeavam o produto de
origem para explicar uma decisão — nada renderizado, nada de código —, e a guarda reprova assim mesmo,
de propósito: comentário viaja na imagem.

**Como não cair:**
1. **"Rodei a suíte" só é verdade sobre um comando e um commit.** Diga qual: *"`tests/pj`, 894, em
   `80cbc20`"* é uma afirmação; *"a suíte está verde"* é uma impressão.
2. **Antes de deploy, a completa, sozinha e sem path.** Não é preciosismo: é o único momento em que o
   acúmulo de várias mãos é medido junto.
3. **Registre o hash em que ela rodou.** Com branch compartilhada o HEAD é alvo móvel — commits
   chegam enquanto ela roda, e o pytest coleta na largada. Se algo entrou depois, meça o **delta**
   (rodar só o que chegou) em vez de fingir cobertura ou re-rodar 30 min.
4. **Quando alguém perguntar "você rodou a suíte completa?", a resposta honesta vale mais que o
   deploy.** Aqui a pergunta veio de outra sessão e segurou uma publicação que teria levado dois
   vazamentos de marca ao ar.

**Sinal de que você está no erro:** o número que você repete (`894`) é menor que o total do projeto
(`3508`), e você nunca reparou porque nunca viu os dois juntos.

**Relacionado:** [[detector-de-trava-nasce-frouxo-e-vacuo-ao-mesmo-tempo]] e
[[fail-open-esconde-teste-vacuo]] — a guarda que ninguém roda é prima da guarda que nasce vácua: nos
dois casos existe proteção escrita que não protege nada, e as duas passam verde pelo mesmo motivo
(ninguém mediu se ela chega a olhar o alvo).
