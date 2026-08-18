## Substituição mecânica de identidade (fork/rebrand) falsifica log histórico e inverte os seus próprios comentários {#sed-identidade-falsifica-historico}

tags: fork, rebrand, renomear produto, sed, find replace, substituicao em massa, migracao de marca, comentario invertido, log de incidente, copy de marketing, llms.txt, revisar diff, telefone hardcoded

**Contexto:** ao derivar um produto de outro, você roda uma substituição em massa de nome, domínio e
slug sobre o repositório inteiro. Os testes passam e o grep fica limpo — mas o resultado tem três
classes de estrago que nenhum teste pega:

1. **Seus próprios comentários viram mentira.** Você escreve "o fork herdou aqui a API do Produto A"
   e o script troca por "do Produto B", invertendo exatamente o sentido do aviso.
2. **Log histórico é falsificado.** Um comentário que reproduz saída real
   (`[REMOTE_LOGOUT] device Produto_A`, com timestamp) passa a registrar um evento que nunca
   aconteceu. Documentação factual vira ficção.
3. **A copy fica sintaticamente certa e semanticamente absurda:** "Transforme sua família em uma
   empresa milionária"; "Produto B — plataforma de gestão financeira pessoal e familiar", nome novo
   com a descrição do produto antigo.

**Solução:**

- Nos comentários que você escrever, refira-se ao outro produto como **"o produto de origem"**, sem
  citar o nome. Assim o teste de identidade pode ser **estrito** (falhar em qualquer menção) sem
  conflitar com a documentação.
- Em log ou histórico reproduzido, anonimize o identificador (`device <do produto de origem>`) em
  vez de trocar o nome — preserva o fato sem afirmar coisa falsa.
- Em documento que lista **vários** produtos do mesmo grupo (termos de uso, mapa de produtos), o
  produto novo é **acrescentado**; ele não substitui o irmão que continua existindo.
- **Leia o diff, não só o resultado do grep.** Grep limpo é condição necessária, não suficiente.

**Irmão:** número de telefone e JID hardcoded não casam com padrão de nome nem de domínio, e escapam
de qualquer varredura por marca. Procure também por identificadores numéricos, ou o usuário do
produto novo vai cair no WhatsApp do antigo.

**Ref:** Empresa Milionária, Fase 0, 2026-08-11. O número do produto de origem estava em 8 telas: o
review cross-provider pegou 1, o grep por número pegou as outras 7.
