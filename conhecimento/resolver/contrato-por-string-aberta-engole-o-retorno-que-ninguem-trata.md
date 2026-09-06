## Contrato de dispatch por string aberta engole o retorno que ninguém trata — e `--strict` não vê {#contrato-por-string-aberta-engole-o-retorno-que-ninguem-trata}

`tags: dispatcher, handler, contrato entre modulos, Literal, assert_never, mypy, tipo aberto, codigo morto, bot mudo, teste de junta, R23`

**Sintoma:** uma funcionalidade some sem erro. O usuário faz a ação, o sistema aceita, e **nada
acontece** — sem resposta, sem mensagem de falha, sem exceção. Os testes de unidade do componente
passam. Os testes do roteador passam. A funcionalidade tem implementação completa e testada.

**Causa raiz:** o orquestrador e o handler combinaram por **string aberta**. O handler devolve
`result="pass"` (ou `"error"`, `"skip"`, `"retry"`); o orquestrador só conhece `if result ==
"handled"`. Todo valor produzido e não tratado cai num `else` que não existe — a mensagem é
consumida e o fluxo termina em silêncio.

**Por que nenhum teste pega:** *o teste do handler passa (ele funciona), o teste do roteador passa
(ele roteia), e ninguém testa a junta.* É incompatibilidade de contrato entre **dois módulos
individualmente corretos** — invisível para qualquer suíte organizada por módulo.

**Por que o type checker também não pega — a parte contraintuitiva:** `result: str` é uma anotação
**honesta**. O campo é mesmo uma string. `mypy --strict` passa sem uma queixa, inclusive num
repositório onde a camada inteira foi levada ao strict com revisão adversarial por fatia.
**Tipar não é fechar.** Rigor de tipagem não protege desta classe enquanto o tipo for aberto.

**Medido em Plexco Tasks (2026-09-06):** os comandos `/foco`, `/sair`, `/desfazer` e `x` do bot de
WhatsApp estavam configurados no roteador e mortos há meses — casavam a rota e morriam em
`result="pass"`. E a mesma diferença de conjuntos revelou um caso pior: `result="error"`, produzido
**quando a criação do registro falha**, também não era tratado — o caminho de falha do fluxo
principal respondia silêncio, que para quem mandou a mensagem é indistinguível de sucesso.

### A checagem que expõe, em um comando

Enumere o que os handlers **produzem** e cruze com o que o orquestrador **trata**. Todo valor
produzido e não tratado é caminho morto:

```bash
rg -o 'result="[a-z_]+"' <dir_dos_handlers> | sort -u
rg -o 'result == "[a-z_]+"' <arquivo_do_dispatcher> | sort -u
```

É `rg` mais uma diferença de conjuntos, não auditoria. Rode em qualquer base que tenha
handler/plugin/consumer registrado por tabela ou config.

### O fix que elimina a classe (em vez de reduzi-la)

1. Feche o tipo: `Literal["handled", "pass", "error"]` no lugar de `str`.
2. Trate exaustivamente com `match` e `assert_never` no ramo final — aí o próprio checker acusa,
   em tempo de análise, todo valor produzido e não tratado.
3. Se o contrato admite só duas respostas, prefira `bool` ou `Optional[T]`: um `bool` não tem
   terceiro valor, e o defeito deixa de ser **expressável**.

Um produto irmão auditado no mesmo dia deu negativo nesta checagem exatamente por isso — os
contratos de dispatch dele eram `-> bool` e `-> str | None`. A proteção foi acidental, não
deliberada; o que importa é que o contrato não admite o defeito.

### Ao consertar, desconfie do comentário

No mesmo arquivo, o comentário que fechava a função dizia `# Fallback to Triagem when external
plugin error or returned pass` — e o código embaixo **não fazia fallback nenhum**. Comentário que
descreve o caminho morto costuma ser o fóssil da geração anterior, quando aquilo era verdade.

**Ver também:** `bot-whatsapp-mudo-sem-erro-e-o-jid-do-device-que-mudou`,
`anotar-handler-fastapi-cria-response-model-e-muda-o-contrato`.
