## Delegação de domínio recusada com a tela do admin visivelmente correta — ela vale por WORKSPACE, não por domínio de e-mail {#delegacao-de-dominio-vale-por-workspace-nao-por-dominio}

`tags: google workspace, delegacao de dominio, domain-wide delegation, service account, unauthorized_client, invalid_grant, gmail api, impersonation, tenant, R23`

**Sintoma:** a delegação em todo o domínio está **na tela**, conferida em print: client ID certo,
escopos certos, salva há horas. E o pedido de token com `sub=<usuario>` continua devolvendo
`unauthorized_client`. Propagação não explica (passou de 24h ou o operador jura que fez cedo), e
reconferir a tela não move nada — porque o defeito não está no que a tela mostra.

**Causa raiz:** a delegação vale **no Workspace (tenant) onde foi registrada**, e uma organização
com dois domínios costuma ter **dois Workspaces distintos**, não um com dois domínios. Registrar no
tenant A e personificar um usuário do tenant B falha, mesmo com o mesmo client ID e os mesmos
escopos. O caso medido: service account criada num projeto do Google Cloud do tenant A
(`percus.com.br`), delegação autorizada no admin do tenant A, e a aplicação personificando
`info@` do tenant B (`ads4pros.com`), criado semanas depois.

🔑 **O erro do Google já discrimina — e quase ninguém lê assim:**

| resposta em `oauth2.googleapis.com/token` com `sub=` | significa |
|---|---|
| `invalid_grant` | o usuário **não existe** para o Google |
| `unauthorized_client` | o usuário **existe**, mas a delegação não vale **no tenant dele** |

Receber `unauthorized_client` no endereço real e `invalid_grant` num endereço inventado do MESMO
domínio **prova** que a conta existe e que o problema é de tenant, não de usuário. E
`unauthorized_client` em **todos** os escopos (não em um só) elimina erro de digitação de escopo:
escopo errado derrubaria um, não todos.

**O teste que localiza o tenant certo, em segundos e sem deploy:** peça token com `sub=` variando a
conta, em cada domínio candidato. A conta que devolve `OK` revela onde a delegação está valendo de
fato:

```
info@dominio-a.com     -> unauthorized_client   (existe, delegacao nao vale aqui)
naoexiste@dominio-a.com-> invalid_grant         (controle: usuario falso)
moacir@dominio-b.com   -> OK                    (a delegacao esta NESTE tenant)
```

**Duas correções, e a escolha depende de quem vê o remetente:**
1. **Registrar a mesma delegação no admin do outro tenant** (mesmo client ID, mesmos escopos). Uma
   service account pode ser autorizada em vários Workspaces de forma independente — autorizar num
   não mexe no outro. É o certo quando o remetente é visto por terceiros (alinhamento DKIM).
2. **Personificar uma conta do tenant onde a delegação já vale.** Destrava na hora, sem acesso de
   admin ao outro Workspace. O custo é o remetente mudar de domínio — **irrelevante se todos os
   envios forem alertas internos**, e vale medir isso antes de decidir: rastreie os destinatários
   reais (`to:`) em vez de supor. No caso medido, os 4 pontos de envio mandavam para endereço da
   própria empresa, com o e-mail do lead só em `replyTo`.

**Não faça:** reconferir a tela do admin pela terceira vez (ela está certa); nem esperar propagação
quando o erro é `unauthorized_client` num usuário que existe — propagação e tenant errado produzem a
mesma mensagem, e só o teste por conta separa os dois.

**Ref:** ADS4PROS `/new-partner`, 2026-09-05. A delegação estava correta desde o começo — no
Workspace errado. Diagnosticada por eliminação com 4 pedidos de token, depois de a tela do admin ter
sido conferida duas vezes sem achar nada.
