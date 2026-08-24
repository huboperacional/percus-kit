## Autenticou no provedor central, e não existe no produto {#autenticou-mas-nao-existe-aqui}

`tags: auth, onboarding, convite, multi-tenant, 401, primeiro acesso, identidade federada`

**Classe:** autenticação federada / primeiro acesso
**Medido em:** 2026-08-24, Empresa Milionária — custou **seis dias** de diagnóstico errado

**Sintoma**

A pessoa recebe o código, digita, e a tela diz **"código inválido"**. Ela pede outro. E outro.
O código nunca funciona.

No log do provedor de identidade, ao mesmo tempo:

```
otp.request.accepted   destino = o numero certo
otp.validate.ok        outcome=success
```

**Zero** falhas de validação. O código sempre esteve certo.

**A causa**

O produto resolve um **usuário local** a partir do token e, não achando, devolve 401. Quem foi
convidado e nunca entrou não tem usuário local — o convite é uma linha numa tabela de convites,
não uma conta.

E aí fecha o círculo: as rotas do lado do convidado (listar convite, aceitar convite) dependem da
dependência que exige usuário. **Para aceitar o convite é preciso já ser usuário; para virar
usuário seria preciso aceitar o convite.** Não há caminho — e não para um usuário específico:
para *todos* os convidados.

**Por que demora tanto a achar**

Três mentiras empilhadas, cada uma plausível:

1. **A tela culpa o código.** Quase sempre o `try` cobre a validação **e** a chamada seguinte:

   ```js
   try {
     await validateOtp(...)        // passa
     const me = await api.me()     // 401
   } catch {
     toast.error('Código inválido')   // <- mente sobre qual das duas falhou
   }
   ```

2. **O convite está impecável.** Número certo, prazo válido, mensagem entregue. Quem olha o
   convite conclui que o problema é o código.
3. **O 401 é genérico por design.** *"Sempre 401, nunca 404"* é a decisão certa contra
   enumeração de contas — e ela apaga a diferença entre *"token ruim"* e *"não existe cadastro
   para esta identidade"*, que é exatamente a diferença que importa aqui.

**O conserto**

**Uma rota de primeiro acesso, com uma dependência que valida o token sem exigir usuário local.**

Não é autenticação mais fraca: assinatura, emissor, audiência e validade continuam conferidos. O
que ela deixa de exigir é o *cadastro*, que é outra pergunta. Usar a dependência normal ali seria
pedir à porta trancada que abrisse a si mesma.

```
POST /usuarios/primeiro-acesso
  identidade autenticada + convite ATIVO para aquele destino -> cria o usuario
  sem convite ativo                                          -> 404 "nao ha cadastro"
```

🔑 **O convite é a fronteira de segurança, e ela é o desenho inteiro.** Se qualquer identidade
autenticada virasse usuário, bastaria ter um número e pedir um código para entrar no produto.
Quem autoriza a entrada é quem administra — nunca o fato de a pessoa ter provado o telefone.

**Provisionar não é aceitar.** A rota cria o usuário e devolve o convite para ser aceito por
`POST` explícito. `GET` que concede acesso é disparado por prefetch de navegador, preview de link
e antivírus corporativo — a pessoa ganharia papel sem ter clicado.

**Três coisas que o conserto tem de incluir**

1. **A mensagem certa no 404.** *"Não encontramos cadastro para este número"* mais o caminho para
   o cadastro. Um erro que não diz o que fazer manda a pessoa pedir outro código para sempre.
2. **Separar os `try`.** Depois da validação bem-sucedida, **nada** pode culpar o código. Vale um
   comentário na fronteira dizendo isso, porque a próxima pessoa vai querer juntar de novo.
3. **Idempotência.** O identificador do usuário costuma ser UNIQUE; dois cliques ou um F5 dariam
   erro de integridade — 500 na cara de quem entra pela primeira vez na vida.

**Como saber que é este caso, em um minuto**

Compare os dois lados **no mesmo instante**:

| Provedor de identidade | Produto | Diagnóstico |
|---|---|---|
| `validate.ok success` | 401 | **é este caso** |
| falha de validação | — | código errado mesmo |
| nada | — | o pedido nunca chegou |

Se não houver falha de validação no log do provedor, **o código não é o problema** — por mais que
a tela diga que é.

**Relacionados**

- [[status-de-sucesso-nao-prova-efeito]] — a mesma família: aceitação não é efeito
- [[404-por-design-esconde-tenancy]] — por que o 401 genérico é certo e ainda assim atrapalha
- [[guarda-herdada-pode-exigir-o-defeito]]
