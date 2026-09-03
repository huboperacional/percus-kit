## O recorte de teste é escrito por quem despacha {#o-recorte-de-teste-e-escrito-por-quem-despacha}

`tags: subagente, despacho, recorte de teste, cobertura, verde falso, suite lenta, delegacao, guarda transversal`

**Sintoma:** o subagente rodou os testes que você mandou, todos verdes — e uma guarda que roda na
suíte padrão estava vermelha o tempo todo.

**O caso** (Empresa Milionária, 2026-09-02): a suíte inteira leva ~25 minutos, então o despacho
dizia *"rode os arquivos das suas tasks mais `tests/pj/test_schema_pj.py` e
`tests/pj/test_isolamento_fk.py`"*. Escolha a dedo, bem-intencionada. Só que
`tests/pj/test_rls_cobertura.py` **não estava na lista** — e estava vermelho, nomeando as quatro
tabelas novas que faltavam em `TABELAS_COM_TENANT`. A guarda funcionou por três commits;
**ninguém a chamou**.

**A regra:** quem despacha escreve o recorte, e **só inclui as guardas que conhece**. O subagente
não tem como saber que existe uma guarda que você não citou — ele obedece à lista. O buraco não é
dele: você transferiu um mapa incompleto para alguém sem contexto para questioná-lo.

**O que fazer:**

- **Não monte o recorte de memória.** Antes de despachar:
  `ls tests/<area>/ | rg -i "cobertura|schema|isolamento|guarda|rls|harness"`. Guarda costuma ter
  nome que a denuncia.
- **Inclua as guardas transversais sempre**, mesmo que a task "não as toque" — elas existem
  justamente para pegar o que ninguém achou que tocava.
- **Escreva o PORQUÊ da lista no despacho.** Um subagente que entende que a lista não é
  burocracia avisa quando um nome não existe — foi o que aconteceu: um deles devolveu *"esse
  arquivo não existe, usei estes dois"*, corrigindo um erro do despachante.
- Suíte lenta não justifica recorte permanente: rodá-la inteira **uma vez ao fim da fatia** custa
  menos que descobrir depois.

Ver também [[tres-jeitos-de-uma-guarda-produzir-verde-falso]] e
[[conte-os-vermelhos-guarda-que-passa-vazia]].
