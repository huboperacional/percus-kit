## Gate por monkeypatch tem de rodar NO processo que ele patcheia {#gate-por-monkeypatch-precisa-do-mesmo-processo}

`tags: gate, monkeypatch, smoke, teste em producao, HTTP, uvicorn, processo, falso verde, criterio de pronto, R23, verificacao, mutation test`

**Contexto:** um critério de pronto do tipo *"desligue X à força e veja a métrica cair"* — a forma
canônica de provar que X é mesmo a causa, e não uma correlação. Escrevi um script que fazia
`monkeypatch` na função de atribuição e depois chamava o endpoint por `urllib` contra
`http://localhost:8000`.

**Causa raiz:** o patch ficou no **processo do script**; a requisição HTTP foi atendida pelo
**uvicorn já em execução**, que tem a sua própria memória e nunca viu o patch. O gate mediu o
código original duas vezes.

**O que torna isto caro:** a saída não parece defeito. Deu `86,9% → 86,9%` — e "o número não mudou"
lê como **estabilidade**, não como "o experimento não aconteceu". Eu quase reportei o critério como
aprovado.

**Correção:** chamar a função **em processo**. No caso, importar a fábrica de sessão do próprio app e
invocar o orquestrador direto, sem passar por HTTP. Aí o gate disparou: `86,9% → 6,0%`.

**Regra prática:** se o gate mexe em código *do servidor*, ou você chama a função no mesmo processo,
ou reinicia o serviço com o defeito reintroduzido. Chamada HTTP a um processo que você não patcheou
não prova nada — e o resultado "não mudou" é **indistinguível de sucesso**.

**Cheiro que denuncia:** um gate cujo "antes" e "depois" dão **exatamente** o mesmo número merece
suspeita antes de comemoração. Gate que não pode falhar não é gate — ver
[[validador-confirma-string-nao-o-sistema]].
