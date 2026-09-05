## Débito de linter medido de um ponto de entrada só é piso, não total {#debito-de-linter-medido-de-um-ponto-de-entrada-so-e-piso}

tags: mypy, tipos, baseline, medicao, divida-tecnica, python

**Sintoma.** Você congelou o débito de uma ferramenta que segue imports (`mypy`,
`pyright`, `tsc` com `--noEmit`) num baseline por módulo, o CI ficou verde, e
semanas depois aparece um módulo que **falha o strict sem estar no baseline**.
Parece regressão nova. Não é: nunca foi medido.

**Causa.** O comando que você usou pra gerar o baseline recebeu **um arquivo** (ou
poucos), e a ferramenta alcançou o resto do projeto **seguindo os imports daquele
arquivo**. Tudo que aquele ponto de entrada não importa — direta ou
transitivamente — ficou invisível. Módulos típicos que escapam: workers, comandos
de CLI, handlers registrados por string/decorator, e serviços que só a API chama.

Caso real (Plexco Tasks, 2026-09-05): baseline gerado com
`mypy --strict backend/tests/test_audit_calls_on_task_handlers.py` deu **910 erros
em 146 módulos**, número que virou o tamanho declarado do plano de pagamento. Ao
executar a 5ª task, o implementador reparou que `wa_bot.py`, `wa_commands.py`,
`wa_routing.py`, `websocket/events.py`, `workers/pix_renewal_link.py` e
`utils/redis_lock.py` falhavam sem bloco no baseline. Medição de verdade:
**mais 29 erros em 6 módulos**. O "910" era piso.

**Conserto.** Gere o baseline apontando a ferramenta para o **pacote inteiro**, não
para um arquivo:

```bash
# errado -- so alcanca o que este arquivo importa
mypy --strict backend/tests/test_alguma_coisa.py

# certo -- varre o pacote
mypy --strict backend/app/
```

E confira a diferença antes de fechar o número:

```bash
mypy --strict backend/app/ 2>&1 | grep -c ': error:'
```

**Prova de que o baseline está completo.** Depois de gerar, rode a varredura do
pacote inteiro **com o baseline já ativo**. Tem que sair `exit 0`. Se sobrar erro,
o que sobrou é exatamente o que a medição de um ponto de entrada não enxergou.

**O que NÃO fazer ao descobrir.** Não acrescente os módulos faltantes ao baseline.
A regra "o baseline só encolhe" é o que impede o débito de voltar a crescer, e um
guard-rail de contagem vai (corretamente) recusar bloco novo. Módulo que ficou de
fora deve ser **corrigido** quando a fatia chegar nele. O que muda é o **tamanho
declarado do plano**, não a regra.

**Por que passa despercebido.** O hook de pre-commit que roda a ferramenta
normalmente a alimenta com os **arquivos staged**, então ele reproduz exatamente o
mesmo viés: enquanto ninguém commitar um dos módulos órfãos, o débito deles nunca
aparece. Verde de hook não é prova de cobertura.

Relacionado: [zero-so-vale-como-prova-com-controle-positivo](zero-so-vale-como-prova-com-controle-positivo.md)
— mesma família: um instrumento cego devolve o resultado que você queria.
