## Regra que o canon declara "automática" e não tem hook é decoração — e a metade sem hook de um par é a que falha {#regra-declarada-automatica-sem-hook-e-decoracao}

`tags: canon, enforcement, hook, R9, R12, spec-analyze, council-pre-mortem, pre-plan-exit, CONSTITUICAO Sec. 6, auditoria de regras, gate [S], decoracao`

**Sintoma:** o agente deixa de fazer algo que o canon manda fazer *"sozinho, sem pedir permissão"* —
e ninguém percebe até um humano perguntar. No caso medido: escrever uma spec, publicá-la e
apresentá-la **sem rodar `spec-analyze`**, com a regra escrita em três lugares
(`01_REGRAS_INEGOCIAVEIS.md:316`, `v2/CONSTITUICAO.md:35`, `v2/loops/spec.md`).

**A parte que dói:** as duas obrigações estavam na **mesma frase** —

> *"ao finalizar uma **spec** → roda `spec-analyze`; ao finalizar um **plano** → roda
> `council-pre-mortem`. Sempre, sem perguntar."*

— e só **uma** ganhou hook (`pre-plan-exit`, PreToolUse:ExitPlanMode). A outra ficou dependendo de
alguém lembrar. Não é filosofia: é metade de um par que ficou pela metade, e a metade sem hook é
exatamente a que falhou.

**A auditoria completa (2026-09-12), cruzando as 25 regras contra os hooks e o gate.** Esta tabela
e a FONTE (R25): o plano e o changelog apontam para ela em vez de recopiar os numeros -- a correcao
de hoje precisou de tres edicoes em tres arquivos, que e exatamente como copia diverge.

| | Quantas | Leitura |
|---|---|---|
| Com enforcement mecânico | 11 | R1, R2, R3, R5, R6, R7, R8, R9, R11, R20, R23 |
| Arquiteturais (R14-R19, R21) | 7 | o R11 cobre no review de código — hook próprio seria custo sem ganho |
| **Comportamentais descobertas** | **7** | R4, R10, R12, R13, R22, R24, R25 |

**Erre a conta e você perde o argumento:** a primeira versão desta auditoria dizia 9 / 7 / 6 — que
soma **22**, não 25, e omitia duas regras. Foi o review cross-provider que pegou, revisando o
documento da própria auditoria. Contagem de auditoria sai do cruzamento mecânico, nunca de memória;
um doc que cobra rigor e não fecha a própria soma desarma sozinho o que estava defendendo.

**A ironia que fecha o argumento:** a **R12** diz *"se uma regra não tem como você verificar
objetivamente que cumpriu, ela é decoração"*. R12 não tem verificação nenhuma. A meta-regra é
decoração pelo critério que ela própria define.

**Como auditar isso, em dois comandos (ambiente POSIX -- no Windows, use Git Bash/WSL ou o
equivalente `Get-ChildItem hooks\*.ps1 | Select-String "R$n"`):** para cada regra `R<N>`, veja se algum
hook ou gate a cita —

```bash
for n in $(seq 1 25); do
  hits=$(grep -rl "R$n\b" hooks/*.ps1 gates/*.sh 2>/dev/null | xargs -r -n1 basename | tr '\n' ' ')
  printf "R%-3s %s\n" "$n" "${hits:-— SEM HOOK/GATE}"
done
```

E, no sentido inverso, procure as **promessas de automatismo** que ninguém cumpre:
`grep -rnE "autom[áa]tic|sem pedir permiss|SEMPRE" <arquivos do canon>`.

**O que NÃO fazer com o resultado:** sair criando hook para as 14 sem enforcement. Regra de arquitetura
(*"rate limit canônico"*, *"magic link centralizado"*) é verificada por review de diff, e hook
próprio ali é custo sem ganho. E gate novo que dispara em massa no primeiro dia **vira escape
declarado** — foi o que o teto do `CONTEXT.md` ensinou. Hook novo nasce **warn-only**, e a promoção
a bloqueio é decisão separada, tomada depois de medir quanto a frota reclama.

**Discriminante:** o texto da regra diz *"automaticamente"*, *"sempre"*, *"sem pedir permissão"*?
Então ela afirma que **não depende de ninguém lembrar** — e essa afirmação é verificável: ou existe
um hook, ou a regra está mentindo sobre si mesma. Regra que descreve disciplina ("prefira X") não
precisa de hook; regra que descreve **automatismo** precisa, porque é isso que ela promete.

Ver [[checkpoint-persiste-arquivos-nao-reseta-contexto]] para a outra metade desta sessão, onde a
ferramenta existia e o que faltava era a medição.
