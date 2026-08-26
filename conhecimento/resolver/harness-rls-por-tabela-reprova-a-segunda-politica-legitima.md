## Harness de auditoria de RLS escrito "uma política por tabela" reprova pra sempre a segunda política aditiva legítima {#harness-rls-por-tabela-reprova-a-segunda-politica-legitima}

tags: postgres, row level security, harness, script de auditoria, multipla politica, FOR SELECT
aditiva, falso positivo, veredito permanente, gucsEsperadas

**O padrão que engana:** um script de auditoria de RLS que testa "cada tabela tem a política
certa" naturalmente se escreve assim: pra cada tabela, calcula o CONJUNTO de GUCs/condições
esperadas da categoria dela (`gucsEsperadas`), pega TODAS as políticas que o `pg_policies` devolve
pra essa tabela, e testa cada política contra esse único conjunto esperado. Funciona perfeitamente
enquanto for verdade que **cada tabela tem no máximo uma política**.

**O buraco:** no dia em que uma tabela ganha legitimamente uma SEGUNDA política — o padrão
`FOR ALL` de base mais uma `FOR SELECT` aditiva, escopo mais estreito, por um motivo diferente
(ver [[rls-with-check-nao-existe-para-delete]] pro porquê de precisar ser uma segunda política e
não uma cláusula a mais na primeira) — o laço aplica o conjunto esperado da categoria BASE contra
a política ADITIVA também. A aditiva nunca vai bater: ela foi desenhada de propósito pra não ler os
GUCs da base e pra não ter `WITH CHECK`. O resultado são dois achados falsos
(`chave-a-menos`, `sem-with-check`) que nunca desaparecem, e o veredito geral daquela tabela — e
frequentemente do harness inteiro, se o cálculo for "reprovado se qualquer achado" — fica
**REPROVADO permanentemente**, mesmo com o desenho correto e intencional.

```python
# ERRADO: testa toda politica da tabela contra o UNICO conjunto esperado da categoria base
for politica in politicasDaTabela:
    faltando = gucsEsperados - gucsQueAPoliticaLe(politica)
    if faltando:
        achados.append("chave a menos")   # falso positivo pra politica aditiva de escopo menor

# CERTO: politica aditiva se identifica pelo NOME (convencao {tabela}_{sufixo_aditivo})
# e e' pulada aqui -- ela ja tem checagem PROPRIA, separada, em outro lugar do script
for politica in politicasDaTabela:
    if politica["policyname"] in nomesDePoliticasAditivasConhecidas:
        continue  # validada por uma funcao dedicada, com o conjunto esperado dela mesma
    faltando = gucsEsperados - gucsQueAPoliticaLe(politica)
    ...
```

**Por que isso passa despercebido até rodar contra banco real:** o laço "uma política por tabela"
não é um bug em si — era correto no dia em que foi escrito, e continua correto pra toda tabela que
nunca ganhou uma segunda política. A quebra só aparece quando outra parte do sistema (uma política
aditiva nova) muda a premissa implícita que o laço nunca declarou. Nenhum teste sem banco pega
isso: é preciso rodar o harness de verdade contra `pg_policies` populado com as DUAS políticas.

**Custo se não corrigir:** o harness continua funcionando como ferramenta manual (sem gate de
CI), mas todo operador que rodar `-m postgres`/o script depois vê vermelho permanente numa tabela
correta — e aprende a ignorar aquele vermelho especificamente, o que é o primeiro passo pra
ignorar um vermelho real que apareça do lado.

**Ref:** Empresa Milionária, Frente A (primeiro acesso via WhatsApp provado), achado no Task 6,
corrigido na revisão final do branch, 2026-08-26. `scripts/harness_schema_rls.py`,
`.superpowers/sdd/2026-08-26-primeiro-acesso-rls-whatsapp-provado/progress.md`.
