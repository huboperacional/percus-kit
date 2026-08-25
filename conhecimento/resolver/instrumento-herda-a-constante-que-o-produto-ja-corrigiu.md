## O instrumento herda a constante que o PRODUTO já corrigiu — e o teste passa a medir o produto errado {#instrumento-herda-a-constante-que-o-produto-ja-corrigiu}

`tags: fork, produto derivado, constante herdada, fixture, e2e, playwright, auth.setup, audience, storageState, medicao invalida, falso diagnostico, producao quebrada que nao esta quebrada, teste de integracao, vazamento de marca`

**Sintoma:** um teste de ponta a ponta acusa produção quebrada — 401 em tudo, "sessão expirou", "código não chegou", timeout numa tela que abre no navegador. Você mede, confirma, quase reporta. E o defeito está **no instrumento**: ele aponta para o produto de ORIGEM, não para este.

**Causa raiz:** em produto nascido de fork, a correção acontece em **duas** camadas com donos diferentes. O código de produção é corrigido cedo — tem review, tem teste, alguém sente a dor. O **fixture** não: ele "funciona", ninguém olha, e a constante herdada sobrevive dentro dele por semanas depois de o produto já ter mudado.

🔑 **O sinal de alarme é o comentário de conserto no arquivo VIZINHO.** Se você encontra, no código de produção, um comentário do tipo *"era X e sobreviveu a toda a troca"*, procure a mesma constante nos fixtures **imediatamente**. Ela está lá.

**Quatro faces do mesmo defeito, todas em 2026-08-25, todas no mesmo produto:**

| O que o fixture herdou | O sintoma que ele fabricava |
|---|---|
| Navegava para a rota do painel de **pessoa física** | Timeout de 30s. A tela abre, saúda com o vocabulário errado e fica **inteira em esqueleto**, porque lê tabela que não existe neste produto |
| Pedia a **audience do produto de origem** no login | Token com `aud` errada, 401 em toda rota, tela dizendo *"sua sessão expirou"* — **indistinguível de a cadeia de autenticação estar quebrada** |
| Lia o OTP de um **JID fixo** do produto antigo | *"Código não chegou"*. Chegava: a audience nova entrega de **outro remetente**, e o helper procurava na conversa errada |
| O **cabeçalho** do arquivo afirmava a regra velha | Ensinava, em prosa, o erro que o corpo do arquivo acabou de consertar |

**Fix:** ao portar ou derivar, trate **fixture como código de produção** para efeito de varredura. Especificamente:

1. **Grepe as constantes do produto de origem no diretório de testes**, não só em `src/`. Nome do produto, audience, ids de device, JIDs, rotas do domínio antigo.
2. Onde a constante existe nos dois lados, **importe** em vez de recopiar — é o mesmo remédio que o projeto já aplica a normalizadores.
3. Quando um sintoma de teste apontar para produção, **leia o valor que o instrumento está usando antes de acusar** — o `aud` do token, a URL que ele navegou, o id do device que ele consultou.

⚠️ **A parte cara não é o conserto, é o diagnóstico.** Cada uma das quatro faces produziu um relatório plausível de "produção quebrada", e duas quase foram entregues. Reportar defeito inexistente custa a confiança que faz o próximo relatório ser lido.

**Irmão comum:** o fixture que injeta credencial direto no storage para "pular o login" **pula justamente o passo sob teste**. Se o que se mede é a cadeia de primeiro acesso, o atalho remove a etapa que cria o usuário — e o resultado é 401 legítimo sobre um produto que funciona. Atalho de fixture escolhe o que NÃO é medido.

**Ref:** Empresa Milionária (fork da Família Milionária), 2026-08-25. Verbete irmão sobre medição que engana: [medicao-no-meio-da-transicao-esconde-defeito](medicao-no-meio-da-transicao-esconde-defeito.md).
