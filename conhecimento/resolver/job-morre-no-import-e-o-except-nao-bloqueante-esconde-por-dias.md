## Um job morre no IMPORT e o `except` "não-bloqueante" esconde por dias {#job-morre-no-import-e-o-except-nao-bloqueante-esconde-por-dias}

`tags: cron, scheduler, job silencioso, except nao-bloqueante, import falha, syntax error, python 3.11, 3.12, f-string, PEP 701, barra invertida, imagem docker, skew de versao, suite verde, docker build nao executa, alerta por ausencia, watchdog, monitor surdo`

**Contexto:** o gerador de diagnóstico diário (`fca_generator`) parou de produzir em 12/08 e ninguém
percebeu até 19/08 — **7 dias**. A tabela de saída ficou completamente vazia no período. Nenhum
alerta disparou, nenhum serviço caiu, o health check seguiu 200, e o scheduler seguiu anunciando os
26 jobs normalmente.

**Causa raiz:** um commit introduziu uma f-string com **barra invertida dentro da parte de
EXPRESSÃO**:

```python
f"  ação: {MAPA.get(chave, 'sem mutation (\"mutation\": null).')}"
```

Isso é legal a partir do **Python 3.12** (PEP 701) e é **`SyntaxError` no 3.11** — a versão da
imagem. Um `SyntaxError` no módulo derruba o **import inteiro**, não uma função.

**Por que passou por todas as barreiras, uma a uma:**

1. **A suíte local passou.** A máquina de dev roda 3.14, onde a construção é válida. Verde local
   não diz nada sobre a versão da imagem.
2. **O `docker build` passou.** O Docker **copia** o arquivo; não executa o módulo. A imagem sobe
   "boa" e o defeito só aparece quando alguém importa.
3. **O `except` "não-bloqueante" engoliu.** O scheduler protege cada job com try/except para que um
   job ruim não derrube os outros 25 — proteção correta. Mas ela converteu uma **queda total** num
   log `ERROR` diário que ninguém lê.

**Como detectar rápido, quando desconfiar:**

```bash
# 1. o job produz? olhe a TABELA DE SAÍDA por dia, não o log
select date_trunc('day', created_at)::date, count(*) from <tabela_de_saida>
where created_at > now() - interval '20 days' group by 1 order by 1 desc;

# 2. o módulo importa DENTRO da imagem que está no ar?
docker exec $(docker ps -qf name=<servico>) python -c "import <modulo>; print('ok')"

# 3. qual versão a imagem realmente usa?
docker exec $(docker ps -qf name=<servico>) python -V
```

**Gate que fecha a classe** (não só esta linha): varra por AST as partes de expressão de toda
f-string do serviço e reprove barra invertida **enquanto a imagem for 3.11** — lendo a versão do
**próprio Dockerfile**, para que subir a base faça o teste mandar reescrever a regra em vez de
continuar verde sem sentido.

```python
def _fstrings_ofensivas(texto: str) -> list[int]:
    return [n.lineno for n in ast.walk(ast.parse(texto))
            if isinstance(n, ast.FormattedValue)
            and "\\" in (ast.get_source_segment(texto, n.value) or "")]
```

⛔ **`ast.parse(..., feature_version=(3, 11))` NÃO serve** — medido: aceita as duas construções. A
regra mudou no **tokenizador**, e `feature_version` só restringe a gramática.

⚠️ **Duas asserções que o gate precisa ter, ou ele é decorativo:**
- **cardinalidade antes do veredito** — um varredor que não acha arquivo nenhum passa verde e não
  prova nada; "limpo" e "não olhei" ficam indistinguíveis;
- **o teste de regressão tem de chamar o detector REAL**, não reimplementá-lo. Um teste que
  reimplementa passa mesmo quando o detector quebra — é espelho, não gate.

**A lição maior que o bug:** o defeito consertado é pequeno; a lacuna que ele expôs não. **Não
existe alerta para job que PARA DE PRODUZIR.** Todo monitor olhava erro, saúde e réplica — nenhum
olhava ausência de escrita. Um job pode morrer no import, no `return` cedo, ou por filtro que passou
a excluir tudo, e em qualquer desses casos o sistema inteiro parece saudável. Quando um job tem
saída persistida, **vigie a saída**, não o processo.

**Relacionadas:** `#validador-confirma-string-nao-sistema` · `#monitor-surdo-pro-que-nasceu-quebrado`
