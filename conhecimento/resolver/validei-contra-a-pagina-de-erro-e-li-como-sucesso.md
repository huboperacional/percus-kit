## Validei a varredura contra o corpo do erro 500 e li "zero ocorrências" como sucesso {#validei-contra-a-pagina-de-erro-e-li-como-sucesso}

`tags: verificacao, falso verde, curl -o, HTTP 500, grep, rg, ausencia de match, medicao, criterio negativo, pagina de erro`

**Sintoma:** você troca um texto em várias superfícies, roda `curl` para um arquivo e depois `rg "termo antigo"` nele. Sai **zero ocorrências**. Você declara limpo. Só que a troca não tinha pegado — e um pedaço do texto antigo continuava no ar.

**Causa raiz:** o `curl` gravou o corpo de uma resposta **500** (a página de erro do framework), e a página de erro obviamente não contém o termo antigo. A varredura funcionou perfeitamente; ela só varreu o arquivo errado. Como o critério era **ausência**, o erro produziu exatamente o resultado que se esperava do sucesso.

🔑 **Critério de ausência é o único que a falha total satisfaz.** "Não achei o termo" é indistinguível de "não achei nada, porque não havia nada para achar". Qualquer verificação cujo verde seja um zero precisa provar, antes, que estava olhando para conteúdo real.

**Solução — duas linhas que fecham a classe inteira:**
1. **Capture o status junto com o corpo, sempre**, e trate qualquer coisa fora de 2xx como medição inválida em vez de resultado:
   ```bash
   curl -s -o /tmp/x -w "status %{http_code} bytes %{size_download}\n" "$URL"
   ```
2. **Prove que o alvo tem conteúdo** com um controle positivo — algo que TEM de estar lá. Se o termo que deve existir também não aparece, a medição está morta, não o defeito resolvido:
   ```bash
   rg -c "termo que DEVE existir" /tmp/x   # se der 0, pare: o arquivo nao e o que voce pensa
   rg -c "termo que NAO deve existir" /tmp/x
   ```

⚠️ **Corolário para varredura de repositório:** "varri e não achei" só vale para o que foi varrido. Uma varredura de marca feita em 5 páginas e nos chunks delas foi declarada — corretamente, com o limite dito em voz alta — e depois tratada como cobertura. O termo estava vivo em 21 lugares num arquivo de dados que não fazia parte das 5. **Declarar o limite não o remove:** ou a varredura cobre `src/` e `public/` inteiros, ou a conclusão é "não achei em X", nunca "não existe".

⚠️ **Em Git Bash, `grep` não casa acento** e devolve zero em português sem reclamar — outro verde falso pela mesma porta. Use `rg` em qualquer varredura cujo critério seja ausência.

Relacionado: [verificacao-pos-deploy-mente-por-cache-de-borda](verificacao-pos-deploy-mente-por-cache-de-borda.md), [contagem-zero-sob-rls-force-nao-e-fato](contagem-zero-sob-rls-force-nao-e-fato.md).
