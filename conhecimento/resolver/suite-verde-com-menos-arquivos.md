## Suíte VERDE com menos arquivos que a baseline não é sucesso — é worker que não subiu {#suite-verde-com-menos-arquivos}

tags: vitest verde falso, worker timeout, failed to start forks worker, contagem de arquivos caiu,
suite parcial passa, pool threads, contencao de maquina, jest workers, npm test mente

**Sintoma:** a suíte imprime verde perfeito — `Test Files 25 passed (25)`, `Tests 109 passed (109)`,
zero falha — mas a baseline era **47 arquivos / 187 testes**. Você acabou de mexer numa primitiva
compartilhada, então a leitura fácil é "quebrei alguma coisa e o runner parou antes". A leitura
oposta, igualmente errada, é aceitar o verde e commitar.

**Causa raiz:** os workers **não subiram**. Sob contenção de máquina (deploy + subagentes + review
cross-provider ao mesmo tempo), o pool de *forks* estoura o timeout de handshake e o runner
simplesmente **não executa** aqueles arquivos:

```
[vitest-pool]: Failed to start forks worker for test files .../OtpLoginPage.test.tsx.
Caused by: [vitest-pool-runner]: Timeout waiting for worker to respond
```

Medido em 2026-08-19: **22 workers perdidos, 0 falhas de asserção**. A degradação foi progressiva em
corridas seguidas conforme a máquina carregava — 47/187 → 45/172 → 25/109. O runner conta só o que
rodou, então perder metade da suíte vira um **número menor**, nunca um vermelho: o modelo de saída
dele não tem casa para "não executado".

**Solução:**
- **Trave a baseline em CONTAGEM DE ARQUIVOS**, não em "passed". Arquivos a menos ⇒ verde falso,
  independente do que o resumo diga. Isto é o gate; o resto é mitigação.
- Use `--pool=threads` (não faz fork por arquivo). Na mesma árvore, a corrida voltou a 47/187 com
  zero worker perdido.
- **Não deixe N subagentes rodarem a suíte cheia em paralelo** — N × suíte É a contenção que produz
  o falso-verde. Delegue `tsc` (barato, incremental) e rode a suíte **uma vez, centralizada**, no fim.

**Corolário que vale além do runner:** `$?` depois de um pipe mede o ÚLTIMO comando do pipe.
`npx tsc --pretty false | tail -5; echo $?` imprime o status do `tail` e **mascara erro de
compilação** — na mesma sessão isso mostrou `tsc=0` com o erro visível na tela logo acima. Quando o
exit code é a evidência, rode sem pipe.

**Por que é a mesma família de outros verbetes:** verde é uma afirmação sobre o que rodou, e nunca
sobre o que não rodou. Ver `#falsificacao-verde-porque-outra-camada-barrou` (o teste mede a coisa
errada) e `#harness-de-ataque-com-corpo-incompleto-da-verde-falso` (o harness não chega no alvo).
Aqui o mentiroso é o **placar**.
