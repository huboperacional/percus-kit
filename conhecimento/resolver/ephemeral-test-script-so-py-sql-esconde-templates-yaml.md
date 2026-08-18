## Script de teste "só código" (.py/.sql) contra Postgres efêmero derruba TUDO que renderiza template ou lê YAML de tenant — 138 falsas-falhas de uma vez {#ephemeral-test-script-so-py-sql-esconde-templates-yaml}

`tags: postgres efêmero, TDD, TemplateNotFound, tenants yaml, test-debt, dbTestsEphemeral,
packaging gap, falsa falha, medir antes de corrigir`

**Contexto:** tiatendo, sessão 2026-08-04. Ao investigar um item de backlog ("48 testes quebrados
pré-existentes, medido X semanas atrás, nunca atacado") rodando a suíte completa contra um
Postgres efêmero real (schema do zero + todas as migrations, via script próprio que sobe um
container throwaway e roda pytest dentro), o resultado inicial foi **198 falhas** — quatro vezes
mais que o esperado. Antes de tratar isso como "198 bugs reais pra corrigir" (o que teria sido um
desperdício monstruoso de esforço perseguindo fantasma), a causa raiz foi investigada primeiro:
**169 das 198** eram `jinja2.exceptions.TemplateNotFound`.

**Causa raiz:** o script de empacotamento (`find execution tests scripts -type f \( -name '*.py'
-o -name '*.sql' \)`) só copiava pro container efêmero os arquivos `.py` e `.sql` — nunca os
templates `.html` (Jinja2) nem os YAMLs de config de tenant (`tenants/*.yaml`). A imagem BASE do
container (reaproveitada só pelas dependências Python já instaladas, pra não pagar `pip install`
toda vez) tinha os templates de uma versão ANTIGA do código — qualquer rota que renderizasse um
template criado DEPOIS dessa versão base quebrava com `TemplateNotFound`, e qualquer teste/fixture
que resolvesse config de tenant pelo YAML em disco (não só via `tenantLoader.getTenant()` em
memória) quebrava do mesmo jeito. Depois de corrigir o find pra incluir `.html` e não excluir
`tenants/`, a contagem caiu de 198 → 60 → 2 (as 2 últimas eram um segundo caso da MESMA classe:
arquivos `.mp3` reais em `static/`, excluído de propósito por tamanho — 33MB de imagens/CSS/JS).

**Sinal de alerta pra generalizar:** quando uma suíte roda contra um ambiente EFÊMERO/isolado
(container throwaway, banco fresco, sandbox) e a contagem de falhas é MUITO maior que o esperado
ou muda pouco entre execuções distantes no tempo mesmo com o código evoluindo bastante, suspeite
do PRÓPRIO AMBIENTE de teste antes de tratar cada falha como bug independente. Agrupe as falhas
por TIPO DE ERRO (não por nome de teste) primeiro — `grep -c "TemplateNotFound"` levou 30 segundos
e mudou o problema de "198 investigações" pra "1 gap de packaging + um punhado de casos reais".

**Solução:** ao escrever/manter um script de "empacota só o necessário pro ambiente efêmero" (por
motivo legítimo de tamanho/velocidade de transferência), audite explicitamente TUDO que o runtime
da aplicação lê em disco além de `.py`: templates (`.html`/`.jinja`), configs (`.yaml`/`.json`),
fixtures de teste que abrem arquivo direto. Excluir por tamanho (ex.: `static/` com imagens) é
válido — excluir por "só código" sem essa auditoria não é.

**Relacionado:** o mesmo processo de investigação achou, DEPOIS de eliminar o artefato de
packaging, um segundo artefato NÃO-relacionado (2ª causa sistêmica descartada por medição, não
suposição): `TestClient(app).post(...)` contra rotas com `BaseHTTPMiddleware` (csrf/csp) — ver
memória `feedback-testclient-basehttp-middleware-drops-post-body` do projeto — que no fim das
contas NÃO apareceu nas falhas reais (tinha sumido junto com o artefato de packaging, não era uma
3ª causa independente). Lição: ter 2 hipóteses de causa sistêmica documentadas ANTES de escavar
falha por falha evitou gastar tempo tentando "consertar" um artefato de ferramenta como se fosse
bug de produto — mas a única forma de saber QUAL hipótese realmente se aplicava foi medir de novo
depois do 1º fix, não assumir que as duas contribuíam.

**Ref:** tiatendo, sessão 2026-08-04, P12 do `docs/PENDENCIAS.md`. Fix do script (untracked,
`scratchpad/dbTestsEphemeral.sh`) + achado colateral de 1 bug de produto real no meio da limpeza
(criar item de cardápio COM variações pelo painel admin dava 500 — `aliases` perdido numa chamada
Python direta que não passa pela injeção de dependências do FastAPI, commit `61cd12c`).
