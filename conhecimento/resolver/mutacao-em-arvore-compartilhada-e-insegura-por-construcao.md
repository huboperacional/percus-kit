## Mutação em árvore compartilhada é insegura por CONSTRUÇÃO — não por descuido {#mutacao-em-arvore-compartilhada-e-insegura-por-construcao}

`tags: mutacao, teste, worktree, contaminacao, multi-janela, subagente, bytecode, falso-verde, R23`

**Sintoma:** você lê um arquivo do repo e ele contém um texto que **você não escreveu** — muitas
vezes exatamente o mutante que o *seu* script produziria. Ou: a suíte quebra com falhas em arquivos
que você não tocou, citando identificadores que o `grep` não acha no fonte.

### O que aconteceu (tIAtendo, 2026-09-06, 4 janelas no mesmo repo)

- Uma janela teve o **restore morto no meio**: um arquivo de `execution/` ficou mutado por minutos, e
  o `.pyc` do mutante sobreviveu à restauração → **33 falhas fantasma** em arquivos intocados.
- Os **subagentes** de outra janela rodaram **dois ciclos** de mutação sobre os mesmos dois arquivos
  numa janela de ~5 minutos. Uma terceira janela leu, nesse intervalo, um arquivo com o mutante
  dentro — e os dois alvos ficaram com `mtime` **idêntico ao milissegundo**, assinatura de um restore
  em lote que não era dela.

🔑 **"Eu" × "meu subagente" não existe para contaminação: o subagente roda na MESMA árvore.** Quem
contou só as mutações que rodou "com as próprias mãos" deu informação errada de boa-fé, e a correção
só veio ao varrer os artefatos do scratchpad.

🔑 **A janela que contaminou seguiu o procedimento inteiro** — backup, restauração byte a byte,
`os.utime`, purga de `__pycache__` — **e ainda assim** expôs o arquivo às outras. Não é disciplina:
é que o objeto medido é compartilhado enquanto se mede.

### O custo que isso tem

Não é só perder tempo. É **veredito invertido**: começar a medir sobre a mutação de outra pessoa faz
o teste já nascer vermelho, e o placar credita a morte a quem não a causou. O pior desfecho não é
errar o placar — é o placar sair **certo por acaso**.

### Como fechar

1. **Mutação só em cópia isolada** (`git worktree add --detach <dir> HEAD`). A árvore principal
   **nunca** é escrita, e o runner **prova** no fim, por `sha256`, que ela ficou intocada.
2. **Hash do alvo ANTES, DURANTE e DEPOIS.** `DURANTE` tem de **diferir** de `ANTES` — se não
   diferir, o `replace` não pegou e "SOBREVIVEU" seria artefato da régua, não veredito. `DEPOIS` tem
   de ser **igual** a `ANTES`.
3. **ABORTAR se o alvo já vier mutado.** O discriminante é **CONJUNTO**: âncora **ausente** *e*
   mutante presente. ⚠️ "Mutante presente" sozinho dá **falso VERMELHO** — o texto de um mutante do
   tipo "apaga a linha de cima" é *substring* da própria âncora.
4. **A cópia nasce do HEAD**, então copie por cima o que ainda não foi commitado (código em curso,
   testes novos, e o `scratchpad/` se o wrapper de banco mora lá). Sem isso o runner mede uma árvore
   **sem a frente** que ele acha estar medindo: baseline vazio, tudo "sobrevivendo", e o placar
   parecendo um resultado.
5. **Remova o runner antigo do repo.** Deixá-lo mantém a foot-gun a um comando de distância.

Implementação de referência: `tiatendo/scripts/mutacaoIsolada.py` (+ teste próprio do runner em
`tests/test_00agRunnerMutacao20260906.py`).

### Relacionados

- `fixture-que-mente-faz-a-mutacao-mentir-junto.md` — quando o corpus **compensa** o mutante.
- `heredoc-citado-do-bash-come-barra-invertida.md` — outra classe de edição programática que mente.
