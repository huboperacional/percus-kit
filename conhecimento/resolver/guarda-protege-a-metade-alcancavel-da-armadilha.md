## A guarda protege a metade ALCANÇÁVEL da armadilha — e a outra metade é onde ela morde {#guarda-protege-a-metade-alcancavel-da-armadilha}

`tags: RLS, row level security, multi-tenant, contexto de transacao, primeiro acesso, convite, deadlock de autorizacao, guarda parcial, comentario que documenta a armadilha, SQLite sem RLS, defeito estrutural`

**Sintoma:** você acha um defeito e, ao abrir o arquivo, encontra **um comentário descrevendo exatamente essa armadilha** — escrito por quem passou ali antes, com a defesa aplicada logo abaixo. A defesa está certa. E o defeito continua vivo, algumas linhas ACIMA dela.

**O caso que nomeia o verbete.** Rota de primeiro acesso: cria o usuário local de quem foi convidado e nunca entrou. Ela faz **duas** leituras da tabela de convites, que está sob RLS:

```python
usuario = await ProvisionarPrimeiroAcesso(session).executar(...)   # leitura 1 — SEM contexto

# O contexto de usuário ANTES de ler `convites_empresa`: ela tem RLS e esta
# consulta roda sem empresa nenhuma. É o mesmo caminho que fez o `minhas_empresas`
# devolver lista vazia em produção com a suíte verde.
await aplicarContextoDoUsuario(session, usuario.id)                 # leitura 2 — COM contexto
convites = await ListarMeusConvites(session).executar(...)
```

Quem escreveu **conhecia a armadilha** — o comentário cita o incidente anterior pelo nome. E protegeu a leitura 2. A leitura 1 ficou sem defesa **porque era estruturalmente impossível defendê-la do mesmo jeito**: ela roda antes de o usuário existir, e a defesa disponível (`aplicarContextoDoUsuario`) precisa de um id de usuário.

**Causa raiz — e é por isso que a revisão não pega:** a defesa é aplicada **onde ela cabe**, e a ausência dela fica **onde ela não cabia**. Quem lê o arquivo vê a armadilha citada, vê o remédio aplicado, e conclui que o assunto foi tratado. O olho para de procurar exatamente onde deveria começar.

📌 **Guarda aplicada é evidência de que o autor sabia, não de que o caso foi coberto.**

**Fix — a pergunta que fecha a classe:**

> Achou uma defesa contra uma armadilha? **Conte quantas vezes a armadilha aparece no caminho, e verifique cada uma.** Depois pergunte: existe alguma ocorrência onde este remédio **não teria como** ser aplicado?

Se existir, essa é a que está viva. Não é esquecimento — é impossibilidade, e impossibilidade precisa de remédio diferente, não do mesmo remédio repetido.

**O formato do remédio diferente**, quando a defesa depende de uma identidade que ainda não existe: uma **prova declarada** — um contexto setado a partir de algo que já foi validado (o token), depois da autorização, morrendo com a transação. É o mesmo desenho de um `app.papel_provado`: não é a identidade, é o registro de que a autorização já aconteceu.

⚠️ **E a política tem dois lados.** A prova que deixa a pessoa **ler** o que é dela não deve deixá-la **escrever**: `USING` sim, `WITH CHECK` não. Senão a fresta aberta para enxergar o convite também deixa carimbá-lo como aceito sem nunca ter virado usuário.

**Por que a suíte não vê nada disso:** SQLite não avalia política nenhuma. As duas leituras devolvem a linha, o caso de uso funciona, e o teste fica verde. Só PostgreSQL de verdade separa a leitura protegida da desprotegida — ver [rls-sem-force-dono-ignora-politica](rls-sem-force-dono-ignora-politica.md) e [contagem-zero-sob-rls-force-nao-e-fato](contagem-zero-sob-rls-force-nao-e-fato.md).

**Ref:** Empresa Milionária, `app/modules/pj/rotas_convite.py` + `app/casos_uso/provisionar_primeiro_acesso.py`, medido em produção em 2026-08-25.
