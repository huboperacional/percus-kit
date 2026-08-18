## Ao trocar o formato de um valor persistido, pergunte o que a rota NOVA faz com o valor VELHO {#manifesto-guarda-contrato-aposentado}

`tags: migracao de formato, valor persistido antigo, manifesto, contrato aposentado, ENOENT degrada, bug latente, dado velho no campo novo, JSON.parse em valor legado, interpolar valor velho em URL`

**Sintoma.** Nenhum — é justamente o problema. O armazenamento (manifesto, coluna, cache) continua
guardando valores gravados pelo contrato **anterior**, e eles só aparecem quando alguém olha.

Caso real: o manifesto de produção tinha `"hero.video": "tto9XoR9Hwg"` — um id do YouTube cru,
escrito pelo painel antigo, num campo que o contrato novo define como URL. Não quebrou porque a rota
nova trata a entrada como "existe override" → tenta ler o arquivo em disco → **`ENOENT` → cai no
fallback**. Foi sorte projetada: o ramo de ENOENT existia por causa de outro bug antigo.

**A pergunta que separa "degrada" de "explode":** o que a rota nova faz com o valor velho? Se a
resposta for *"interpola numa URL"*, *"faz `JSON.parse`"* ou *"assume o shape novo"*, é bug latente
esperando um dado antigo aparecer — e ele aparece no dia em que ninguém está olhando. Se for *"tenta,
falha e degrada pro default"*, está coberto. **Migração de formato não é só o código novo: é o que
acontece com o que já está gravado.**
