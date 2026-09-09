## 401 de API externa pode ser PLACEHOLDER não expandido virando Bearer — e `${VAR-COM-HÍFEN}` nunca expande {#401-de-api-externa-pode-ser-placeholder-nao-expandido}

`tags: 401, credencial, os.path.expandvars, variavel de ambiente, tenant yaml, ghl, bearer, falha silenciosa, truthy, R23`

**Sintoma:** uma integração externa responde **401** e o time vai investigar a conta — permissões do
token, escopos, expiração, se a chave foi revogada. Nada disso está errado. O que está sendo enviado
no header `Authorization: Bearer` é o **texto literal do placeholder**, tipo
`${GHL_SABOR-DO-TESTE_KEY}`, porque a variável de ambiente nunca foi expandida.

**Reprodução real** (tiatendo, 2026-09-09): `tenants/sabor-do-teste.yaml` trazia
`api_key: ${GHL_SABOR-DO-TESTE_KEY}`. O nome da variável foi derivado do **slug do tenant**
(`sabor-do-teste`) sem converter hífen em sublinhado.

```python
>>> import os
>>> os.path.expandvars("${GHL_SABOR-DO-TESTE_KEY}")
'${GHL_SABOR-DO-TESTE_KEY}'      # devolvido INTACTO
>>> os.path.expandvars("${GHL_ADS4PROS_KEY}")
'x'                               # expande normalmente
```

**Por que hífen quebra:** hífen não é caractere válido em nome de variável de ambiente. `expandvars`
não acha o nome, não erra, não avisa — **devolve a string como veio**. Não existe exceção, não
existe `None`, não existe log.

### As duas metades do defeito, e por que consertar uma não basta

O 401 tinha **dois produtores independentes**, e o diagnóstico inicial só viu um:

1. **O call site que expande e testa com `if`.** `apiKey = os.path.expandvars(...)` seguido de
   `if apiKey and locationId:` — uma string não vazia é **truthy**, então o literal `${...}`
   **passa no teste** e segue direto para o header. A API responde 401 e a tela mostra "HTTP 401".
2. **O call site que nem expande.** Outro caminho no mesmo sistema usava `cfg.get("api_key")` cru.
   Renomear a variável no YAML consertaria o primeiro e deixaria o segundo mandando `${...}`
   exatamente como antes.

🔑 **Um sintoma, dois produtores.** Ao achar a causa de um 401 desses, procure **todos** os pontos
que leem a credencial — `grep` pelo nome do campo, não pelo `expandvars`, senão o call site que não
expande fica invisível justamente por não ter a chamada que você está procurando.

### O conserto que resolve a classe, não o caso

Renomear a variável resolve **o tenant de hoje**. O que resolve a classe é um resolvedor único que
**recusa credencial em forma de placeholder** em vez de deixar cada call site decidir se `${...}`
serve:

```python
def resolveGhlCredential(raw, *, field):
    expanded = os.path.expandvars(str(raw).strip())
    if _PLACEHOLDER.search(expanded):          # ${...} ou $VAR sobreviveram
        raise UnresolvedCredentialError(...)   # falha ALTA, nunca vira Bearer
    return expanded
```

Detalhes que a experiência mostrou serem necessários na mensagem de erro:

- **nomear a variável que falta** — erro genérico obriga a caçar no YAML;
- **avisar explicitamente quando o nome tem hífen.** Sem isso o operador lê "variável não definida",
  vai ao `.env`, define com sublinhado (que o YAML não referencia) e o 401 continua idêntico;
- **nunca carregar o valor.** Erro vai para log e tela; segredo não. Vale mesmo quando o valor é só
  um placeholder, porque no dia em que ele for real a mensagem já estará certa.

### Guarda de classe, barata

Varrer todos os YAMLs de configuração proibindo `${VAR-COM-HÍFEN}`: qualquer referência assim é uma
credencial **garantidamente** quebrada, e sem a varredura ela só aparece como 401 lá na ponta,
possivelmente em produção.

```python
for ref in re.findall(r"\$\{([^}]+)\}", conteudo):
    assert "-" not in ref, f"{arquivo}: ${{{ref}}} nunca expande"
```

### Verbetes relacionados

- [[401-identico-nao-e-env-stale-pode-ser-chave-morta]]
- [[401-em-wrapper-que-herda-env-nao-prova-nada-sobre-a-chave]]
