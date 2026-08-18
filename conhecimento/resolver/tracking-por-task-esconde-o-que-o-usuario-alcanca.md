## Rastreamento por task diz `[4-C]` e o usuário continua vendo o app do fork {#tracking-por-task-esconde-o-que-o-usuario-alcanca}

tags: fork, derivacao, tracking, handoff, plano, frontend, rota orfa, verificacao, curl grep, screenshot, produto no ar

**Sintoma.** O rastreamento do projeto está honesto — cada task com a escala certa, suíte
verde, build verde —, o produto sobe, o operador entra pela primeira vez e encontra **o app do
produto de origem**. Menu, cores e telas do fork, com a logo nova em cima.

**Causa.** Num projeto nascido de fork, o frontend chega **inteiro**. As telas novas nascem ao
lado das herdadas, em rotas próprias, e **nada as conecta**: o login continua apontando para o
dashboard antigo e o menu continua sendo o antigo. Medido num caso real: 42 páginas, **2** do
domínio novo, ambas corretas e **nenhuma alcançável**.

O rastreamento por task não mente — ele descreve **entrega**, não **alcance**. `[4-C]` diz "o
componente existe", e existe. A pergunta que nenhuma escala responde é "o que a pessoa vê ao
logar?".

**Duas medições que expõem isso em segundos, e que valem em todo fork:**
```bash
# 1. quantas telas sao do dominio NOVO?
find src/app -name page.tsx | wc -l
find "src/app/(novo)" -name page.tsx | wc -l

# 2. para onde o login manda?
grep -rn "router.push\|/dashboard" src/app/login/page.tsx | head
```
Se a razão for 2/42 e o login apontar para a tela herdada, o produto **é** o do fork.

**Correção de processo, e é a lição que sobrevive:**

1. **O tracking ganha uma linha que não é por task:** *qual é a primeira tela depois do login,
   e ela é do domínio novo?* Enquanto a resposta for "não", nenhuma fase está perto de fechar.
2. **`curl` e `grep` não verificam tela.** Eles confirmam que uma string existe no HTML — e a
   string foi escrita por quem está verificando. No caso real, a home pública exibia o nome do
   produto de origem no mock de conversa do hero (`Assistente FM`) e a sigla dele num avatar,
   com build verde e 494 testes passando. **Screenshot da tela renderizada, sempre.**
3. **Rota órfã é dívida invisível.** Tela que nenhum menu alcança não aparece em teste de
   navegação, não aparece em analytics e não aparece para o usuário — mas conta como entregue.
   Ao criar rota nova num fork, o link para ela entra na MESMA entrega.

**O que NÃO é a causa, e culpar isso faz perder tempo:** o plano estava certo e a ordem
backend-primeiro estava certa. O que faltou foi dizer em voz alta a consequência —
*"até esta fase terminar, quem loga vê o produto antigo"* — numa linha que o operador lesse
antes de publicar.
