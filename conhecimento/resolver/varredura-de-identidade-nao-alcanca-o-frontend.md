## Varredura de identidade que cobre só o backend deixa o FRONTEND com a identidade do produto de origem {#varredura-de-identidade-nao-alcanca-o-frontend}

`tags: identidade, fork, audience, invalid_audience, varredura, sweep, frontend, backend, login quebrado, produto derivado, 401, teste nao alcanca arquivo`

**Sintoma:** produto derivado por fork tem a troca de identidade "concluída", com teste dedicado
e verde, e mesmo assim o login quebra em produção com `invalid_audience` — ou pior, funciona e
emite token para o produto ERRADO. No caso medido, o frontend pedia
`audience: 'familia'` (o produto de origem) enquanto o backend validava a audience própria: todo
token seria recusado com 401, e nenhum dos 2,7 mil testes acusava.

**Causa raiz — duas frestas ao mesmo tempo, e é a combinação que engana:**

1. **A varredura não alcança o frontend.** O teste de identidade costuma nascer no repo do
   backend e varrer `app/**/*.py`. O frontend nunca esteve no alcance dele — então não é que a
   asserção falhou, é que ela nunca foi executada contra aquele arquivo.
2. **A regex procura o nome COMPOSTO, e o que sobrevive é a string NUA.** Um padrão como
   `familia[-_]milionaria|familiamilionaria` casa domínio e slug, mas **não** casa
   `audience: 'familia'`. O valor perigoso é justamente o mais curto, porque é o identificador
   técnico — e é ele que viaja para o serviço de auth.

Somadas: o teste existe, está verde, e a coisa que ele foi escrito para impedir está no
repositório.

**Como confirmar (evidência, ~20s):**
```bash
# 1. O teste de identidade alcanca o frontend?
grep -n "rglob\|glob\|Path(" <repo>/api/tests/test_identidade*.py   # varre so app/? entao nao alcanca
# 2. Qual audience o frontend pede DE FATO?
grep -rn "audience" <repo>/frontend/src --include=*.ts --include=*.tsx | grep -v generated
```

**Solução:** varredura DIRIGIDA ao valor, não ao nome do produto. Duas asserções e uma guarda:

- **Guarda de cobertura primeiro** — asserte que a varredura achou N arquivos (`assert len > 50`).
  Sem ela, mover ou renomear a pasta do frontend faz o teste passar **vazio**, que é exatamente
  o modo de falhar que originou o defeito.
- **Padrão que casa o VALOR:** `(?:audience\s*[:=]|AUDIENCE\s*=)\s*['"]([a-z0-9\-]+)['"]` e
  compare o grupo capturado com a audience do projeto. Pega as três formas com que alguém
  escreveria isso em `.ts`.
- **Reuse o padrão de domínio do backend em vez de escrever um mais estreito.** O receio de
  falso positivo com `familiaId`/`familia_id` **não se sustenta**: as alternativas do padrão
  exigem `milionaria` logo depois do separador. Estreitar por medo custa as grafias com hífen,
  underscore e acento — e a estreiteza vira o defeito.

**Vale para além de audience:** device de mensageria, slug de produto em link de checkout, chave
de storage, `origin` de identidade provisionada. A regra geral é: **todo valor que o cliente
manda para um serviço COMPARTILHADO precisa de trava no repo de quem manda**, não só no de quem
recebe — o serviço compartilhado aceita os dois produtos por construção e não tem como saber que
o remetente se identificou errado.

**Ref:** Empresa Milionária (fork da Família Milionária), Task 16, 2026-08-14. Achado ao consultar
o auth-service sobre o registro da audience, não por teste. Falsificado nos dois sentidos.
