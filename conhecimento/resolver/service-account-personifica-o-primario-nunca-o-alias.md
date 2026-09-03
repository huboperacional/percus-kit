## Service account personifica o endereço PRIMÁRIO, nunca o alias — e o alias serve no `From` {#service-account-personifica-o-primario-nunca-o-alias}

`tags: gmail, google workspace, service account, delegacao em todo o dominio, domain-wide delegation, alias, invalid_grant, e-mail transacional, credencial, R23`

**Sintoma:** a service account está criada, a delegação em todo o domínio parece configurada, a
chave JSON existe — e pedir token com escopo `gmail.send` devolve
`invalid_grant: Invalid email or User ID`. A leitura natural é *"a delegação não foi feita"* ou
*"falta escopo no Admin"*, e o time vai pedir ao operador que refaça algo que já está certo. Em um
caso real isso escalou até *"precisamos contratar o Workspace para este domínio"* — quando o
Workspace já existia.

**Causa raiz:** o `subject` da personificação tem de ser um **usuário real** do diretório, e
**alias não é usuário**. Um endereço como `suporte@empresa-nova.com.br` pode ser apenas um alias de
`suporte@empresa-mae.com.br`: entrega e-mail perfeitamente, aparece no Admin, e mesmo assim o
diretório não o resolve como identidade. A delegação está correta o tempo todo; quem está errado é
o endereço passado como `subject`.

**Como confirmar em 30 segundos, sem enviar nada:** peça só o token, para os dois endereços.

```python
from google.oauth2 import service_account
import google.auth.transport.requests as gr

for assunto in ["alias@dominio-novo.com", "primario@dominio-mae.com"]:
    try:
        cred = service_account.Credentials.from_service_account_file(
            SA_JSON, scopes=["https://www.googleapis.com/auth/gmail.send"], subject=assunto)
        cred.refresh(gr.Request())
        print("OK   ", assunto)
    except Exception as e:
        print("FALHA", assunto, "->", str(e)[:120])
```

O `refresh` falha na origem quando a delegação não vale — então **token obtido já prova a
delegação, sem mandar e-mail nenhum**. É diagnóstico barato e não observável por terceiros.

**Solução:** separe os dois papéis em configuração, porque eles são coisas diferentes:

- `GOOGLE_SUBJECT` — **quem a service account personifica**. Endereço **primário** do diretório.
- `GOOGLE_REMETENTE` — **o que aparece no `From`**. Aqui o alias vale, e normalmente é o que você
  quer que o cliente veja.

Guardar um só valor e usá-lo nos dois lugares é o que produz o sintoma: funciona no `From`,
quebra na personificação.

**Armadilha vizinha, do mesmo dia:** o caminho da chave em `GOOGLE_APPLICATION_CREDENTIALS` era
relativo (`chave.json`) enquanto o arquivo morava na raiz do repositório e o processo subia de um
subdiretório. Nunca resolvia — e o erro que isso gera é genérico o bastante para ser confundido com
problema de credencial. **Caminho de chave em configuração: absoluto, ou relativo à raiz declarada,
nunca ao cwd de quem por acaso executou.**

**Custo se ignorar:** dias de ida e volta pedindo ao operador para reconfigurar Admin, com risco
real de decisão cara e desnecessária (contratar plano, criar domínio, trocar provedor) para
resolver um erro de uma linha de configuração.

Relacionado: [[401-em-wrapper-que-herda-env-nao-prova-nada-sobre-a-chave]],
`variavel-ausente-no-shell-pode-estar-no-arquivo-de-ambiente` (verbete nao escrito).
