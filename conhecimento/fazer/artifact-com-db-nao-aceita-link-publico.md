## Artifact que declara `db` NÃO pode ser compartilhado por link público {#artifact-com-db-nao-aceita-link-publico}

`tags: artifact, claude.ai, db, capability, compartilhamento, link publico, cliente externo, aprovacao, R23`

**Quando isto morde:** você publica uma página de aprovação/coleta para um **cliente externo** —
tabela com botão de aceite, campo de observação — e usa a capacidade `db` para gravar as respostas
e lê-las depois. A página funciona. Aí o operador abre *Share* e a opção **"Anyone with the link"
está cinza**, com a nota *"This Artifact stores shared data, so it can't be shared publicly"*.

**Causa:** declarar `capabilities: {db: {}}` torna o artifact **organization-internal** por
construção — todo leitor e escritor precisa ser membro logado da organização do dono. É contrato,
não bug: os dados são compartilhados entre visualizadores, então o alcance é restrito.

⇒ **As duas coisas são mutuamente exclusivas:** gravação server-side que você lê depois **ou** link
aberto para alguém de fora.

**Como decidir, antes de publicar:**

| Quem abre | O que usar |
|---|---|
| Alguém da sua organização (ou você, numa call com o cliente) | `db` — respostas gravadas, você lê depois com `read_db` |
| **Cliente externo, sozinho, pelo link** | **sem capacidade nenhuma** + `localStorage` para o rascunho + um botão **"Copiar resposta"** que gera um texto pronto para colar em e-mail/WhatsApp |

**Detalhes que evitam retrabalho no caminho sem `db`:**

- `localStorage` guarda o rascunho **no navegador de quem preenche** e nunca chega até você. A
  página tem que **dizer isso** — nunca escreva "salvo" para algo que só existe no cliente.
- Renderize as linhas em **HTML estático**, não geradas por JS: página de aprovação que depende de
  script para *mostrar* o conteúdo fica em branco se o script quebrar, e o cliente vê uma página
  vazia sem entender por quê.
- ⚠️ **Feche o `</script>`.** O conteúdo é embrulhado num esqueleto no momento da publicação; sem o
  fecho, o markup do wrapper entra dentro do script, ele quebra com erro de sintaxe e **nada** do
  JS roda — botões mortos, contadores vazios, e nenhuma mensagem de erro visível.
