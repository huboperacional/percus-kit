## Guard que casa TEXTO de comando não vê o wrapper que abre a mesma sessão remota — e a regra duplicada divergiu 3× {#guard-de-comando-nao-ve-o-wrapper-que-abre-a-sessao-remota}

`tags: R20, guard de acao externa, PreToolUse, wrapper, sessao remota, vps_exec, bypass por provedor, regra duplicada, PowerShell, ERE, bash, word boundary, underscore como caractere de palavra, fronteira de token, teste de paridade, imposto que acaba desligado, disciplina nao e rede`

**Contexto:** o guard de ação externa (R20) barra a palavra do cliente de sessão remota no **texto
do comando**. É barato, cobre o caso direto, e tem um furo estrutural: **o wrapper do próprio
projeto abre a mesma sessão remota sem carregar a palavra**.

**Sintoma:** o guard bloqueia o comando direto e **passa batido** no wrapper. Medido em
2026-08-21 (Paid Media Automation): `python scripts/vps_exec.py` abre a **mesma** sessão que o
comando barrado, e o texto não contém o token procurado. Não há erro, não há aviso — o caminho
protegido e o caminho livre fazem a mesma coisa.

⚠️ **O agente respeitou o bloqueio e reportou em vez de usar o atalho.** Isso é o resultado certo,
e é exatamente por isso que passa despercebido: **contar com esse comportamento é contar com
disciplina, não com rede.** Guard cuja eficácia depende de o agente não procurar o desvio óbvio não
é guard — é convenção.

### O conserto, e a parte que quase o estraga

Casar também o **wrapper cujo NOME declara destino remoto** (`vps`/`ssh` no nome do arquivo),
**exigindo interpretador na frente**. A exigência do interpretador não é detalhe de implementação —
é o que impede o guard de bloquear `cat`/`grep`/`head` **do mesmo arquivo**. E isso importa mais do
que parece:

🔑 **Guard que impede LER vira imposto, e imposto acaba desligado.** Um guard que barra inspecionar
o próprio script que ele protege gera fricção em toda sessão que só queria entender o código —
até alguém removê-lo por inteiro. A precisão do matcher é o que compra a sobrevivência da regra.

### A parte mais instrutiva: a regra vive em duas linguagens e divergiu TRÊS vezes seguidas

A mesma regra foi escrita em **PowerShell** e em **ERE/bash**, e as duas cópias divergiram em três
rodadas consecutivas — cada divergência sendo um **bypass por provedor**: bloqueava num shell e
liberava no outro.

| # | Onde divergiu | Por quê |
|---|---|---|
| 1 | **fronteira ANTES do token** | uma cópia ancorava o começo, a outra não |
| 2 | **`_` como separador** | `\b` do .NET trata `_` como **caractere de palavra**; `[^[:alnum:]]` do ERE **não** — o mesmo nome com underscore casava de um lado só |
| 3 | **fronteira DEPOIS da extensão** | uma cópia parava no `.py`, a outra seguia |

**As três só apareceram porque foram MEDIDAS** — rodando as duas implementações contra as mesmas
entradas e comparando. A suíte automatizada existia e estava verde: ela cobria **só uma das
linguagens**. Dois lados, um testado, verde permanente, divergência invisível.

**A regra:** **regra de segurança duplicada em duas linguagens precisa de teste NAS DUAS** — e o
teste tem de **comparar as duas saídas**, não afirmar cada uma isoladamente. Sem paridade medida, a
divergência não é observável de dentro de nenhum dos lados, e **ela é o bypass**.

**Corolário de método:** ao endurecer um matcher, escreva a tabela de casos **antes** e rode-a nos
dois motores, incluindo de propósito: o token no meio de um identificador, com `_` colado, com
extensão, e o caso legítimo de **leitura** que precisa continuar passando.

**Relacionado:** [regra-duplicada-ps1-sh](regra-duplicada-ps1-sh.md) — a classe geral da regra
duplicada e a receita de teste de paridade; [guarda-casa-a-mensagem-nao-a-acao](guarda-casa-a-mensagem-nao-a-acao.md)
— o par simétrico deste verbete (lá o guard vê o que não é ação; aqui ele não vê a ação);
[guard-de-texto-acha-a-mencao-antes-do-uso](guard-de-texto-acha-a-mencao-antes-do-uso.md),
[alargar-matcher-de-guarda-troca-miss-por-alvo-errado](alargar-matcher-de-guarda-troca-miss-por-alvo-errado.md)
(mede o que o alargamento QUEBRA, não só o que ele pega),
[guard-legado-word-boundary-colide-nome-novo](guard-legado-word-boundary-colide-nome-novo.md)
(`\b` e `_` mordendo em outro contexto) e
[guard-sem-caminho-alternativo](guard-sem-caminho-alternativo.md).

**Ref:** Paid Media Automation, 2026-08-21 — endurecimento do guard R20 de ação externa.
