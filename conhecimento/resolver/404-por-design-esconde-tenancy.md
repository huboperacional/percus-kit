## 404 "por design" transforma erro de tenancy em bug invisível {#404-por-design-esconde-tenancy}

`tags: multi-tenant, organization_id, 404 vs 403, enumeration, org homonima, RF-17, escopo de org, identity_id, membership, link compartilhavel, deep-link, diagnostico`

**Contexto:** um recurso org-scoped devolve **404 tanto para "não existe" quanto para "existe em outra
org"** — decisão de segurança correta e comum (403 confirmaria a existência do recurso alheio, virando
oráculo de enumeração). Um link legítimo, mandado por WhatsApp/e-mail ao próprio dono do dado, falhava
para sempre com "não encontrado".

**Causa raiz:** **três organizações com o MESMO nome de exibição** ("Hub Operacional"), criadas em
horas diferentes e distinguíveis só pelo `slug` — e um deles nem parecia (`ads4pros`). O canal de
entrada (webhook de WhatsApp) resolveu o remetente por **telefone** e gravou na org A; o browser da
mesma pessoa loga por **e-mail**, numa identidade diferente, com membership só na org B. Duas linhas
de `users` para o mesmo humano, `identity_id` distintos, nenhuma interseção.

**Por que ninguém viu antes:** a UI mostra o **nome** da org, não o id. Três orgs homônimas são
indistinguíveis na tela, no switcher e no log. E o 404 correto por segurança é lido pelo time como
"o dado sumiu" ou "o link expirou" — não como "você está na org errada". A tela ainda dizia *"tente
recarregar a página"*, conselho que nunca resolveria.

**Diagnóstico (a ordem que funciona):**
1. Chamar o endpoint **direto pela API**, com o token do browser, e confirmar o status cru
   (`404 {"detail":"..."}`) — separa problema de front de problema de escopo.
2. `GET /me/organizations` → qual é a org **ativa** e quais a identidade alcança.
3. No banco: `SELECT id, name, slug, created_at FROM organizations WHERE name ILIKE '<nome>'` —
   **é aqui que os homônimos aparecem**; sem este passo você fica procurando bug de código.
4. `SELECT organization_id, identity_id, email, phone FROM users WHERE identity_id = '<iid do JWT>'` vs
   o `user_id` gravado no recurso. Se não houver interseção, o 404 é **permanente**, não timing.

**Fix (dois níveis):**
- **Produto:** link org-scoped deve carregar contexto de org (ou o login deve cair na org que dona o
  recurso). E o front tem que ramificar em `status === 404` com mensagem honesta + saída ("ir para X"),
  em vez de "recarregue".
- **Dado:** consolidar homônimos, ou dar membership. E **proibir orgs com nome idêntico** — ou pelo
  menos exibir o `slug` no switcher quando houver colisão de nome.

⚠️ **Corolário para allowlists por org:** ligar uma feature para `ORG_A,ORG_B` quando o operador só
navega em `ORG_A` faz a feature "funcionar em produção" e ser **invisível para quem testa**. O
registro de deploy dizia "as 2 orgs do operador" — e uma delas não era acessível a ele.

**Ref:** Plexco Tasks s156 — tela da leva `[4-C]` travada 1 sessão inteira por isto, atribuído a
"falta o operador abrir".
