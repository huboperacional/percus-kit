## Com `responseType: 'blob'`, o corpo do ERRO também chega como `Blob` — o `detail.codigo` some {#axios-responsetype-blob-entrega-o-erro-como-blob}

`tags: axios, responseType, blob, download, erro, 409, 503, detail, codigo, envelope, fastapi, frontend, ver documento`

**Sintoma:** a rota que devolve um arquivo (PDF, imagem) é chamada com `api.get(url, { responseType: 'blob' })`. No sucesso,
tudo certo. No erro (409 com `codigo`, 503 com `tipo`), a tela cai sempre no ramo genérico: o leitor de erro do projeto procura
`erro.response.data.detail` e não acha nada, porque `data` é um `Blob`, não um objeto. A recusa nomeada vira "Não foi possível
abrir o documento". Medido em 2026-09-16 (Empresa Milionária, Task 19 da guarda, "Ver documento").

**Causa raiz:** `responseType` vale para a resposta inteira, qualquer que seja o status. O XHR do navegador não sabe de antemão
que a resposta será de erro; o axios entrega os bytes no tipo pedido.

**Solução:**

1. Leia o erro em dois passos: se `erro.response.data instanceof Blob`, faça `JSON.parse(await data.text())` e só então procure
   `detail`. Deixe isso num helper único, usado pela tela do download e por qualquer outra que leia a mesma recusa em JSON.
2. `JSON.parse` dentro de `try`: um proxy pode devolver HTML no 502, e o helper não pode lançar dentro do `catch` da tela.
3. Teste o erro de verdade pelo mock de rede, com o corpo JSON e o `codigo`: afirme a frase NOMEADA e que nada foi aberto.
   Um teste que só cobre o sucesso nunca vê o `Blob` no erro.
