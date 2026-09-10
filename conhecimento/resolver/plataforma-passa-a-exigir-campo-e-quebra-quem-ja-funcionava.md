## Plataforma passa a EXIGIR um campo e quebra quem já funcionava — a suíte fica verde e nada nasce {#plataforma-passa-a-exigir-campo-e-quebra-quem-ja-funcionava}

`tags: api de terceiro, campo obrigatorio, meta, deprecacao, teste da nossa forma, default perigoso, R23`

**Sintoma:** um caminho de criação que funcionava há meses passa a falhar **para todo mundo**, sem
que ninguém tenha tocado nele. A suíte continua verde: ela confere o corpo que **nós** montamos, e
o corpo continua igual ao que sempre montamos. Quem descobre é a primeira chamada real.

**Reprodução real** (Meta Marketing API v22, 2026-09-09, duas de uma vez):

1. **Campo que virou obrigatório.** Criar conjunto passou a exigir a declaração do público
   Advantage: *"defina a sinalização público_advantage como 1 ou 0 no campo
   automação_de_direcionamento"*. Sem `targeting_automation`, o conjunto inteiro é recusado — ou
   seja, **nenhuma campanha nova nascia**, nem pelo assistente da tela nem por script.
2. **Campo que virou proibido.** Pedir `instagram_actor_id` em `fields` devolve *"(#12) Old
   Instagram ID is deprecated for versions v22.0 and higher"* e **mata a requisição inteira** — não
   é campo que volta nulo. O campo vivo é `instagram_user_id`.

E uma terceira, da mesma família: `POST /act_<id>/adimages` decide o formato pela **extensão do
nome do arquivo**, não pelo MIME. Com o arquivo chamado `upload.bin` a resposta é *"Tipo de arquivo
não suportado"* com bytes de JPEG válidos (`ff d8 ff e0`), `content-type: image/jpeg` no download e
o `Blob` declarando o tipo. Renomear para `upload.jpg` resolve.

**A armadilha do default.** Ao adicionar o campo obrigatório, é tentador ligar o recurso "porque a
plataforma recomenda". Não: **o padrão tem de preservar a decisão de quem montou a campanha**.
Advantage ligado autoriza a plataforma a entregar PARA ALÉM do público escolhido; ligá-lo por
omissão troca a escolha do operador por um default do código, e o efeito só aparece semanas depois,
no relatório, como *"o público não era esse"*. Padrão = `0`.

**A armadilha do truthy.** O valor chega de um request JSON. `{"advantageAudience": "false"}` —
string, vinda de um formulário que serializa booleano como texto ou de um payload gravado por outra
versão — é **truthy**. Com `input.x ? 1 : 0` isso liga a expansão sozinho, e o comentário do código
diz o contrário. Use `=== true`, na borda **e** no ponto de uso, e cubra `"false"`, `"0"`, `""`,
`0`, `1`, `null`, `undefined` e `{}` no gate.

**Why:** nenhum teste da nossa forma pega qualquer uma das três. O `Blob` tinha o tipo certo, o
`FormData` era bem-formado, o mock aceitava tudo. É a mesma família de *"teste da nossa forma não
valida contrato de terceiro"*: só a chamada real valida. E o custo é assimétrico — a regra nova
quebra **todos** os caminhos de criação ao mesmo tempo, inclusive os que ninguém está olhando.

**How to apply:**
- Ao ver criação falhar em massa sem deploy nosso, suspeite de **mudança do terceiro** antes de
  suspeitar do nosso código, e leia a mensagem inteira: ela costuma nomear o campo.
- Ao adicionar o campo, escolha o default que **preserva** o comportamento declarado, não o que a
  plataforma promove; e escreva no comentário por quê.
- Emita o campo **sempre**, não só quando o chamador pediu: se a plataforma exige, omitir é recusa.
- Faça a capacidade **atravessar a porta** no mesmo commit (rota → mapeador → biblioteca). Capacidade
  que existe na biblioteca e não chega pela porta é indistinguível de capacidade que não existe.
