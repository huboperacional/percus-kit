## Campo de escrita que SUBSTITUI a coleção inteira — o "adicionar uma tag" que apaga as outras (e derruba uma regra de negócio junto) {#campo-de-escrita-substitui-colecao-inteira}

`tags: api rest, PATCH, substitui lista, replace vs append, tags_to_add, tags_to_delete, _embedded, opt-out apagado, kommo, amocrm, efeito colateral silencioso, campo de leitura usado pra escrita`

**Sintoma:** você "adiciona" um item a uma coleção de um recurso (tags, labels, categorias,
participantes) via PATCH e a chamada responde 200. Só muito depois alguém nota que **os outros itens
da coleção sumiram** — e ninguém liga o sumiço à sua chamada, porque ela fazia outra coisa.

**Causa raiz:** o campo que você usou é de **leitura** (o que a API te devolve no GET), e quando
aceito na escrita ele funciona como **atribuição da coleção inteira**, não como append. A API tem
campos dedicados para mutação granular — geralmente `<coisa>_to_add` / `<coisa>_to_delete` — e eles
costumam ficar num nível diferente do payload.

**Por que isso vira incidente e não bug pequeno:** a coleção apagada quase sempre carrega alguma
**decisão de negócio** que outro trecho do sistema consulta. No caso de referência, o mesmo lead
guardava `nao-contatar`/`opt-out`, e o worker lia exatamente essas tags antes de enviar mensagem.
Resultado: **o ato de enfileirar o lead apagava a evidência que impediria o disparo** — quem pediu
para não ser contatado receberia a mensagem. Nenhum log acusaria nada, porque tecnicamente tudo
"deu 200".

**Como confirmar em 2 minutos, sem depender de doc:** teste controlado num registro descartável.

1. leia a coleção atual;
2. adicione uma tag-sonda com nome óbvio (`teste-nao-apagar`) pelo campo que você acredita ser o de
   append;
3. dispare **exatamente o payload que o seu código manda hoje**;
4. releia. Se a sonda sumiu, é substituição.

Restaure o estado no fim. Esse teste vale mais que a documentação, porque APIs de CRM costumam
aceitar formatos legados não documentados.

**Armadilha irmã, medida no mesmo teste:** o campo certo **no lugar errado** é pior que o errado. Um
`tags_to_add` aninhado dentro de `_embedded` fez a API responder **200 e não fazer nada** — falha
silenciosa idêntica à do `jsonBody` sem `specifyBody`. Confira o NÍVEL do campo, não só o nome.

**Solução:** migre para os campos granulares, na raiz do payload, e transforme a regra em lint de
deploy — a chave errada é invisível em code review (o payload "parece certo"). Vale bloquear a chave
de leitura em **qualquer profundidade**: um regex de proximidade (`"_embedded"[^}]*"tags"`) não
atravessa objeto aninhado e deixa passar justamente o caso mais elaborado.

**Ref:** Kommo-Disparo-WhatsApp, 2026-08-12. Lead com 4 tags ficou com 1 após o PATCH. Bug ativo em
produção, nunca manifestado porque até então só leads de teste sem tag de bloqueio eram enfileirados.
