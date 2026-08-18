## Spec vermelha há semanas: o elemento não sumiu, a PÁGINA não abre (guard de perfil) {#spec-vermelha-rota-inacessivel-por-perfil}

`tags: e2e, spec vermelha, elemento nao encontrado, getByRole nao acha, guard de perfil, superadmin, redirect, storageState fabricado, laudo errado, rota protegida`

**Sintoma:** um spec e2e falha em `elemento não encontrado` e o laudo conclui "o botão foi removido no redesign". O botão **existe** no código-fonte. Semanas depois ninguém consertou, porque "a UI mudou" parece explicação suficiente.

**Causa raiz:** a rota tem **guard de perfil** (`if (user.perfil !== 'superadmin') router.replace('/dashboard')`). O elemento não é encontrado porque **a página nunca renderizou** — o teste já está em outra URL. Agrava: o setup de auth pode **fabricar** o perfil no `storageState` (`perfil: payload.perfil || 'superadmin'`), então o teste "deveria" passar — até o app buscar o perfil real no servidor e redirecionar. E o perfil exigido pode **não existir em nenhum usuário** do banco, deixando a rota inacessível pra todo mundo, inclusive em produção.

**Solução:**
1. **Antes de culpar o seletor, afirme a URL:** `await expect(page).toHaveURL(/\/rota/)` como primeira linha. Falha aí = problema de acesso, não de UI.
2. Cheque o **perfil real no banco** (`SELECT perfil FROM usuarios WHERE ...`) — não o fabricado no storageState.
3. Se a rota é inacessível por decisão de produto, **`test.describe.skip` com o motivo medido** (arquivo:linha do guard + o que o banco diz). Vermelho eterno ensina a suíte a ser ignorada.
4. Rota que exige um perfil que **ninguém tem** é achado de produto, não de teste — reporte.

**Ref:** Família Milionária, 2026-07-29 — `/fluxo-bot` e `/admin` exigem `superadmin`; o operador é `admin` e o banco de prod não tem nenhum superadmin. O laudo anterior dizia "o botão adicionar step não existe mais". Commit `569e4c8`.
