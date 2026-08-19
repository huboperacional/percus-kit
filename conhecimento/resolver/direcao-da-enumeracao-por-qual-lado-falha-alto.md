## A direção da enumeração se escolhe por QUAL LADO FALHA ALTO, não por "allowlist é mais seguro" {#direcao-da-enumeracao-por-qual-lado-falha-alto}

`tags: enumeracao, allowlist, blocklist, lista fechada, direcao da regra, falha muda, fail loud, desconhecido, modelo novo, parametro novo, effort, output_config, R11, politica de risco, guarda, enforcement`

**Sintoma:** você vai escrever uma lista que decide comportamento — quais modelos aceitam um
parâmetro, quais extensões dispensam review, quais caminhos são sensíveis — e aplica o reflexo
"allowlist é a opção segura". Em metade dos casos esse reflexo instala uma **falha muda**.

**Causa raiz:** "allowlist" e "blocklist" não são propriedades de segurança, são direções de
enumeração. O que decide qual usar é **o que acontece com o item DESCONHECIDO** — o que nasce
depois de você escrever a lista. E isso depende inteiramente do domínio:

- **Enforcement (política de review R11, 6.41.0):** o desconhecido passando é o risco. Um arquivo
  de extensão nova escapando da review é dano silencioso. → **allowlist**: dispensa só o que eu
  reconheço como inofensivo.
- **Compatibilidade de parâmetro (`output_config.effort`, 6.42.0):** o desconhecido sendo BARRADO
  é o risco. Modelo novo que cai sem `effort` volta com **HTTP 200 e conteúdo vazio** — a perna
  responde nada e o orquestrador conta como respondida. → **blocklist**: omito só para quem eu
  medi que recusa; o desconhecido recebe, e se recusar a API devolve **400 com o nome do parâmetro
  na mensagem**.

🔑 **O critério é a assimetria entre as duas falhas: uma grita, a outra não.** Prefira sempre a
direção cujo erro chega como exceção, não como resultado plausível. Alto e errado se conserta em
minutos; mudo e errado sobrevive semanas — neste kit sobreviveu um mês (`#regra-duplicada-ps1-sh`).

**A armadilha específica, e ela é de MANUTENÇÃO, não de escrita:** as duas direções vão conviver no
mesmo repositório, e vão parecer uma inconsistência para quem chegar depois. Alguém vai abrir a
lista "errada" e harmonizar com a outra em nome da coerência — de boa-fé, sem rodar nada, porque a
mudança parece cosmética. **Escreva a razão da direção NA PRÓPRIA LISTA**, não no commit e não no
changelog: quem harmoniza está olhando para o arquivo, não para o histórico. Em
`_effort-capabilities.json` isso é o campo `_nota_direcao`, que diz explicitamente para não
harmonizar com a lista fechada do R11 e por quê.

**Teste que prova a direção** (o teste de valor conhecido não prova nada aqui): afira o
**desconhecido**, não os casos da lista. Passe um item que não está em lugar nenhum e verifique que
ele cai no lado alto.

**Relacionado:** [#regra-duplicada-ps1-sh] (a mesma lista em dois interpretadores diverge calada) ·
[#conselho-agent-marker-chamado-por-http] (o caso que originou isto, com a matriz medida) ·
[#cross-claude-400-sampling] (a classe irmã: parâmetro novo demais para o modelo).

**Ref:** percus-kit 6.42.0 (2026-08-19). O 400 foi relatado independentemente por dois projetos
(Familia Milionaria e Micro) antes de ser medido aqui — reincidência em campo é sinal de classe,
não de caso.
