## `401` num wrapper que herda ambiente NÃO prova nada sobre a chave — teste a credencial direto antes de reemitir {#401-em-wrapper-que-herda-env-nao-prova-nada-sobre-a-chave}

`tags: credencial, 401, env, variavel de ambiente, heranca de processo, dotenv, conselho, provider morto, diagnostico errado, R23`

**Sintoma:** um wrapper (script de review, orquestrador de conselho, CLI de deploy) falha com
`401 Unauthorized` chamando um provider. O operador troca a chave. **O `401` continua.** A conclusão
natural — *"a chave nova também é inválida"* — leva a reemitir credencial que está boa, ou a abrir
chamado com o provider.

**Causa raiz:** variável de ambiente é **herdada do processo pai no instante do spawn**. Se a sessão
que dispara o wrapper subiu **antes** da troca, todo processo filho continua recebendo a chave
**antiga**, indefinidamente — e nenhuma edição de `.env`, `setx` ou painel muda isso enquanto a
sessão estiver de pé. Pior: o carregador de `.env` da maioria dos wrappers só preenche variável
**AUSENTE**:

```powershell
if (-not (Get-Item -Path "env:$name" -ErrorAction SilentlyContinue)) {
    Set-Item -Path "env:$name" -Value $val
}
```

Então o `.env` novo é **ignorado em favor da variável velha**. Os dois mecanismos se somam e o
sintoma fica perfeitamente estável.

**Medido em tiatendo (2026-08-25):** a perna DeepSeek do conselho devolvia `401` em toda rodada. O
operador trocou a chave; o `401` permaneceu, e tanto o agente quanto a contraparte de revisão
escreveram que `401` significa *"chave inválida ou revogada"*. Um `curl` direto, com a chave **lida
do arquivo** naquele instante, devolveu **HTTP 200** — a chave estava boa o tempo todo. O
`council-orchestrator.ps1` rodava com a variável herdada de uma sessão iniciada horas antes.

**REINCIDIU em tiatendo (2026-08-26), mesma chave, confirmando a regra.** Operador rotacionou a
`DEEPSEEK_API_KEY` de novo (a antiga tinha vazado no output do agente em 25/08). `.env` do projeto já
tinha a chave nova (confirmado por **sufixo mascarado** — últimos 4 chars, sem nunca imprimir o valor
completo). Rodar `deepseek-review.sh` na mesma sessão devolveu `401` com a chave **antiga** ainda
citada no erro (`****d818 is invalid`) — a sessão do agente tinha subido antes da rotação. Nenhum
`curl` foi necessário desta vez: comparar o sufixo mascarado do `.env` contra o sufixo mascarado do
`os.environ` já discriminou "propagação" de "credencial" sem expor nenhum segredo em texto.

**Discriminante, em uma linha.** Antes de qualquer conclusão sobre a credencial:

```bash
KEY=$(grep '^PROVIDER_API_KEY=' .env | cut -d= -f2-)
curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $KEY" <endpoint-minimo>
```

- **200** → a chave está boa. O problema é de **propagação**, não de credencial: reinicie a sessão,
  ou force `$env:VAR` por invocação. **Não reemita.**
- **401** → aí sim é credencial.

**Distinga também o código:** `401` é autenticação (chave inválida/revogada); `402` é **saldo**.
Carregar créditos resolve `402` e **nunca** resolve `401` — e o inverso também vale: quem vê `401` e
recarrega crédito paga sem consertar nada.

**Regra que fica:** *sintoma observado através de um wrapper que herda ambiente é sintoma do
ambiente do wrapper, não do serviço.* Meça o serviço pelo caminho mais curto possível — sem wrapper,
sem cache, lendo a credencial do arquivo no momento do teste — antes de agir sobre a credencial.

**Contra-regra (não superaplique):** isto vale para **variável herdada**. Se o wrapper lê a chave do
arquivo a cada execução (sem `if -not exists`), a herança não explica nada e o `401` é real.
Confirme qual dos dois é o seu antes de usar este verbete.

Irmãos: [[fixture-que-mente-faz-a-mutacao-mentir-junto]] ·
[[guarda-que-mede-o-eixo-que-ela-mesma-escreve-e-inerte]]
