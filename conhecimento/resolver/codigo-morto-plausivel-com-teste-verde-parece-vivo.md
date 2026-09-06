## Código morto plausível com teste verde parece vivo — meça o call site, não a peça {#codigo-morto-plausivel-com-teste-verde-parece-vivo}

`tags: codigo morto, geracao antiga, teste verde, call site, refactor, aposentar arquitetura, cobertura, R23`

**Sintoma:** você lê o código, encontra a funcionalidade **completa e testada**, conclui que ela
funciona — e ela está desligada há meses. Ou pior: outra pessoa (ou outra sessão) lê o mesmo código
e te passa a informação errada de boa-fé, porque não há nada no arquivo dizendo que ele está morto.

**Causa raiz:** aposentar uma geração de arquitetura quase nunca inclui **apagar** a anterior. O
código antigo fica: importável, coerente, com testes passando. Nada nele é falso — ele só não é
mais **chamado**. E teste verde é lido como prova de que a coisa está viva, quando prova apenas que
a peça faz o que promete.

**Medido em Plexco Tasks (2026-09-06):** **28% da superfície conversacional** (1.306 de 4.723 LOC,
5 módulos) era código morto plausível — incluindo comandos de usuário totalmente implementados e
testados. Um worker registrado no `main.py` rodava **a cada 5 minutos varrendo um namespace Redis
que ninguém mais escrevia**. Um produto irmão auditado no mesmo dia tinha um módulo dormente com
**7 testes passando**; em outro, o código dormente com teste verde era o **próprio harness de
replay** — o instrumento cuja função era pegar regressão, apodrecendo apontado para o lugar errado.

### Os quatro mecanismos (catalogados em 4 produtos no mesmo dia)

| Mecanismo | Como a peça morre sem parecer morta |
|---|---|
| **Import** | nada mais importa o módulo; ele continua correto e testado |
| **Flag** | o gate nasce `False` e nunca é ligado; o caminho existe e não roda |
| **Interceptação** | outra camada passa na frente e resolve antes; a peça nunca é alcançada |
| **Substituição** | uma geração nova assume o papel e a antiga fica registrada em paralelo |

### A contramedida

**Meça o call site, não a peça.** Cobertura de unidade responde *"esta função faz o que promete?"*;
nenhuma responde *"alguém a chama em produção?"*. As checagens baratas, em ordem de custo:

```bash
# 1. quem importa este módulo?
rg -l "from .*<modulo> import|import <modulo>" --glob '!tests/**'

# 2. quem chama a função de entrada dele?
rg -n "<funcao_de_entrada>\(" --glob '!tests/**'

# 3. o registro em config/tabela aponta pra um handler que ainda existe e responde?
#    (ver: contrato-por-string-aberta-engole-o-retorno-que-ninguem-trata)
```

Se o único chamador está em `tests/`, a peça está morta e os testes dela são cobertura fantasma —
sobem o número e não protegem nada em produção.

### Ao encontrar

Não basta "anotar como morto": um comentário `# legado` não impede a próxima pessoa de ler o
arquivo e concluir que funciona. **Ou apaga, ou o registro que rota para ele é removido** — o
perigoso não é o código existir, é ele continuar **alcançável pelo roteador** e responder com
silêncio.

⚠️ E cuidado com o custo escondido: código morto continua pagando manutenção. Os 5 módulos mortos
do caso acima estavam sendo levados a `mypy --strict` fatia por fatia, com revisor adversarial e
conselho cross-provider — esforço inteiro gasto em código que ninguém executa.

**Ver também:** `contrato-por-string-aberta-engole-o-retorno-que-ninguem-trata`,
`repro-fora-da-arvore-inventa-limitacao-de-ferramenta`.
