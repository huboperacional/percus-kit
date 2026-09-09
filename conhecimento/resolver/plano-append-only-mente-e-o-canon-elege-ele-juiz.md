## O `PLANO.md` append-only mente, e o canon elege justamente ele como juiz {#plano-append-only-mente-e-o-canon-elege-ele-juiz}

`tags: PLANO.md, HANDOFF.md, checkpoint, deriva, doc drift, append-only, plano-doctor, reconciliar, R2, R23`

**Sintoma:** você lê o `docs/PLANO.md` pra saber o estado de uma frente e ele diz "não deployado" /
"todas suspensas" / "falta abrir geral" — mas a coisa está em produção há semanas. O documento não
está desatualizado por descuido de alguém: ele está **estruturalmente incapaz** de se atualizar.

**Causa raiz — os dois artefatos têm vidas invertidas em relação ao que guardam:**

| | `HANDOFF.md` | `docs/PLANO.md` |
|---|---|---|
| Vida por design do canon | efêmera — reescrito a cada checkpoint, teto de 150 linhas | permanente — sem teto, sem instrução de poda |
| O que recebe na prática | o fato **durável** ("F1/F2/F3 subiram em prod") | o **status do item**, escrito uma vez |
| Resultado | reescrito ~20x → **esquece** | nunca revisitado → **congela e passa a mentir** |

O fato durável vai parar no documento que o canon projetou pra ser descartado, e o status permanente
fica no documento que o canon não manda revisar. Está trocado.

**O flagrante (Plexco Tasks, medido 2026-09-04):** o commit `6126579`, intitulado *"docs(checkpoint
s150): F1+F2+F3 do Funil LIVE e verificados em prod"*, tocou `HANDOFF.md` e um script de smoke — e
**não tocou o `PLANO.md`**. Seis semanas depois as linhas de item ainda diziam "não deployado".
Mesmo padrão em `54e6715` ("A5 LIVE"), que também só tocou o HANDOFF.

**Números:** 13 afirmações falsas no PLANO, a mais antiga com ~3 meses. Desde a linha falsa mais
antiga, **101 commits tocaram o arquivo** e nenhum voltou nelas. O topo tinha **21 blocos
`_Atualizado em:` empilhados** — append-only não por hábito, mas por estrutura. Do outro lado, o
HANDOFF foi **reescrito 23 vezes** carregando um "cert vence 14/set" que já tinha renovado: reescrever
não salva, porque a reescrita **transcreve** em vez de re-medir.

**E o canon lacra a mentira em vez de pegá-la.** `v2/loops/checkpoint.md` manda *"Reconcilie contra o
`PLANO`, não recopie o `HANDOFF`"* e declara que **"o PLANO vence"**. A regra está certa e até nomeia
esse fracasso — mas a cadeia que ela define é:

```
HANDOFF  ←  PLANO  ←  (nada)
```

Não existe, em lugar nenhum do canon, instrução que reconcilie o **PLANO contra a realidade**. Então
a regra promove a fato qualquer erro que entre nele. Segundo ponto: o teto de 150 linhas é só do
HANDOFF; o diagnóstico do próprio canon (*"meça tamanho, não delta"*) nunca foi apontado ao PLANO,
que virou o arquivo de 2091 linhas.

**Duas famílias de afirmação, e misturá-las é o que faz "lembrar de atualizar" fracassar:**

- **Família A — o git já sabe.** "não deployado", "todas suspensas", "falta abrir geral". São
  **verificáveis por script**. A correção não é disciplina: é parar de guardar em prosa o que é
  derivável, e checar por máquina.
- **Família B — fato com validade.** Validade de certificado, estado de banco, flag de serviço. Não
  sai do git. Correção: **carimbo obrigatório** na própria linha —
  `<!-- verificar-ate: AAAA-MM-DD | como: <comando que re-mede> -->`. O carimbo diz *quando* re-medir
  e *com qual comando*, então re-verificar deixa de depender de alguém lembrar de como.

**Ferramenta que fecha o elo:** `scripts/plano-doctor.py` (Plexco Tasks, ~190 linhas, stdlib pura).
[A] linha que diz "não deployado" citando commit já ancestral da ref de produção → contradição.
[B] carimbo `verificar-ate:` vencido → obriga re-medição mostrando o comando. [C] tamanho e nº de
blocos empilhados → sinal precoce do append-only. Sai 1 em A ou B; roda no checkpoint e no CI.

**Duas armadilhas ao construir um doctor de doc, as duas pagas:**

1. **Verificador barulhento é verificador ignorado — o que recria o problema original.** A 1ª versão
   dava falso-positivo em `"smoke pós-deploy pendente"` (o deploy aconteceu; falta o smoke) e em
   blocos `_Atualizado em:`, que são narrativa histórica datada. Um doctor de doc precisa distinguir
   **status de item** de **prosa histórica**.
2. **O hash citado nem sempre é o trabalho.** Uma linha dizia "branch X (base master `6065d21`)" —
   aquele hash é a **base**, trivialmente em prod. Prefira citar o commit do trabalho.

**Prova de que não é verificador vácuo:** rodado contra a versão pré-saneamento achou 4 contradições,
**2 das quais a varredura manual não tinha pego** — uma parada há ~3 meses. Contra a versão saneada,
zera. Um verificador nunca testado contra um caso ruim não vale como verificação: por isso o doctor
aceita `--arquivo`, pra rodar contra uma versão antiga e provar o RED.

**Discriminante, em uma linha:** o doc afirma um estado que o git ou o serviço podem confirmar
sozinhos? Então não é para estar em prosa — ou vira checagem de máquina (família A), ou ganha carimbo
de validade com o comando que o re-mede (família B).
