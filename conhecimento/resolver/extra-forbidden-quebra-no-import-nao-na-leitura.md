## `extra_forbidden` derruba TODO import, não "quando alguém ler a variável" {#extra-forbidden-quebra-no-import-nao-na-leitura}

`tags: pydantic, pydantic-settings, extra_forbidden, env, .env, boot, import, suite quebrada, config, Settings, deducao vs medicao`

**Contexto:** gravei cinco variáveis novas (`GOOGLE_*`) no `.env` para preparar uma integração, sem ainda declarar os campos em `Settings`. Raciocinei que o estrago viria depois — "quando o código ler a variável". Errado, e a suíte inteira parou.

**Causa raiz:** `extra="forbid"` (via `SettingsConfigDict`) valida o `.env` na **construção** do objeto, não no acesso ao atributo. E a construção acontece no **import do módulo** — o padrão é `settings = Settings()` no fim de `config.py`. Então:

```
variável no .env sem campo em Settings
  → Settings() levanta ValidationError
  → o import de app/core/config.py morre
  → QUALQUER `import app.*` morre junto
  → a suíte inteira, que importa a app, não roda
```

Não há "falha quando alguém usar". Falha em tudo, imediatamente, com `ValidationError: N validation errors for Settings / Extra inputs are not permitted`.

**Fix:** declarar o campo com default seguro **no mesmo commit** em que a variável entra no `.env`, mesmo que nada o leia ainda.

```python
GOOGLE_DRIVE_ROOT_FOLDER_ID: str = ""   # existe mesmo sem consumidor
```

🔴 **NÃO troque para `extra="ignore"` para calar o sintoma.** O `forbid` existe para pegar **typo de variável de ambiente** — `DATABSE_URL` no `.env` de produção com `ignore` ligado é silêncio, e o app sobe com o default. Desligar a guarda para não declarar um campo troca cinco segundos de digitação por uma classe de bug invisível.

⚠️ **Mas o `forbid` só vigia o ARQUIVO `.env` — variável do ambiente do processo passa calada** (medido em 2026-09-16,
Empresa Milionária, `pydantic-settings` com `case_sensitive=True`). Um `BaseSettings` mínimo com `extra` padrão:
`os.environ["VARIAVEL_DESCONHECIDA"]="true"` → **aceita, sem erro**; a mesma variável numa linha do `.env` → `extra_forbidden`.
A fonte de ambiente só lê os nomes dos campos declarados. Consequências:

- O typo `DATABSE_URL` só é pego se estiver no **arquivo**. Em Docker/Swarm com `environment:` (ou `-e`), ele é ignorado e o
  app sobe com o default — exatamente o silêncio que o parágrafo acima atribui ao `ignore`.
- Teste que prova "o campo precisa estar declarado" tem de carregar por **`.env` temporário**
  (`Settings(_env_file=str(tmp_path / ".env"))`), com controle: uma variável inventada no mesmo arquivo tem de derrubar.
  Pelo `monkeypatch.setenv`, esse controle nunca fica vermelho: a variável inventada no ambiente não derruba nada.

**A ordem importa em DEPLOY, e é o inverso:** a variável só pode entrar no `.env` de **produção** DEPOIS de a imagem que conhece o campo estar de pé. Se o Swarm/K8s rolar de volta para a imagem anterior, ela não conhece o campo e o boot morre — o rollback vira outage. Campo primeiro (código), variável depois (ambiente).

**Como se descobre rápido:** `python -c "import app.core.config"`. Se o `.env` tem sobra, a mensagem nomeia cada variável.

**O erro de método por trás, que é o que vale:** eu **conhecia** a regra — tinha citado `extra_forbidden` horas antes, no mesmo dia, como argumento para manter outra variável fora do `.env` de produção. Sabia da regra e **deduzi** o mecanismo em vez de medir. Quem me corrigiu rodou `pytest` e colou o traceback. Convicção sem medição é o defeito; conhecer a regra não protege de errar como ela funciona.

**Ref:** Empresa Milionária, 2026-08-23. Ver também [guarda-de-schema-cobre-por-tipo](guarda-de-schema-cobre-por-tipo.md).
