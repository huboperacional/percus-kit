## Guard novo reprova testes antigos em bloco — quase sempre é a FIXTURE que nunca satisfez a nova pré-condição, não regressão {#guard-novo-reprova-fixture-que-nunca-satisfez-a-precondicao}

`tags: teste, fixture, precondicao, guard, regressao aparente, controle positivo no fixture, suite vermelha, enfraquecer o guard, TDD`

**Sintoma:** você adiciona um guard/pré-condição global e um punhado de testes preexistentes cai
de uma vez. A tentação imediata é achar que o guard está agressivo demais e afrouxá-lo.

**O diagnóstico que decide, e é barato: os testes que caíram falham pela MESMA razão?** Se sim,
quase certamente eles compartilham uma forma de fixture que **nunca satisfez** a pré-condição nova
— porque a pré-condição não existia quando foram escritos. Não é regressão; é cobertura que estava
implícita e virou explícita.

**Caso real (Paid Media Automation, 06/09/2026).** Guard novo: "só conte o dia se alguma conta da
plataforma reportou gasto > 0" (controle positivo). Caíram 3 testes de integração. Os três mediam
coisas diferentes — transição de sinal, janela do dia-alvo, texto da mensagem — e **os três tinham
o mesmo fixture: uma carteira onde NINGUÉM gasta**, porque cada um só semeava o sujeito sob teste.
Nenhum deles falava sobre cegueira de coleta.

**A correção certa: dar controle positivo ao FIXTURE, não afrouxar o guard.** Cada teste ganhou um
vizinho que gasta, o que também deixou o cenário mais parecido com produção (carteira real sempre
tem alguém gastando):

```python
vizinho = pg.cliente("Vizinho Que Gasta")
pg.metrica(pg.conta(vizinho, platform="META", account_id="999"), _alvo_de(0), "500.00")
```

Assim cada teste volta a medir **só a sua propriedade**, com a pré-condição satisfeita de propósito
e visível na leitura.

🔑 **O caso que revela cobertura nova de verdade:** um dos três testava a MENSAGEM de "cliente sem
linha de métrica". Sob o guard, esse cenário tem agora **dois desfechos distintos** — com controle
positivo (a ausência é da conta) e sem (a medição é suspensa). Ele não foi consertado: virou
**dois** testes. Quando um teste antigo não cabe mais em um resultado só, ele estava medindo dois
casos fundidos.

⚠️ **Não afrouxe o guard para a suíte ficar verde.** Se o guard está certo, o veredito mudou de
propósito e a suíte está te contando isso. Afrouxar aqui teria devolvido exatamente o defeito que o
guard existe para matar.

⚠️ **E confira se a falha é de ambiente antes de tudo.** Na mesma execução, 2 dos 5 vermelhos eram
de bundle incompleto (`import schedule_runner` sem o arquivo no pacote enviado) — nada a ver com a
mudança. **Rode a suíte ANTES de escrever os testes novos**: separa "comportamento alterado" de
"teste novo falhando" e de "ambiente quebrado", que é uma separação que economiza horas.

Relacionado: [[controle-positivo-por-dominio-de-falha-do-medidor]], [[gate_must_seen_failing]],
[[test_scope_must_match_change_radius]].
