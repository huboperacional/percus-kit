## Mutante sobrevivente pode ser EQUIVALENTE por defesa em profundidade — e contá-lo como falha lê o placar ao contrário {#mutante-sobrevivente-pode-ser-equivalente-por-gate-duplicado}

`tags: mutacao, mutation testing, mutante equivalente, placar, RBAC, defesa em profundidade, gate duplicado, teste de permissao, falso verde, include_router, fastapi, denominador`

**Sintoma:** você escreve um teste para uma guarda (tipicamente de permissão), ele passa, e o
mutante que **remove a guarda** também passa. A leitura reflexa — e errada — é *"meu teste é
fraco"*, e o conserto reflexo é reforçar o teste, que não muda nada porque o mutante continua
sobrevivendo.

**Causa:** a propriedade está protegida por **duas camadas independentes**, cada uma suficiente
sozinha. Removendo uma, a outra continua produzindo o mesmo comportamento observável. O mutante é
**equivalente** — muda o código, não muda a semântica —, e mutante equivalente **não é matável**,
por construção.

Medido no tIAtendo em 2026-09-08, e o caminho até entender custou duas rodadas:

1. Removi `dependencies=[Depends(requireAbility(...))]` do `@router.post`. **Sobreviveu.**
2. Supus que a camada real fosse o `include_router(..., dependencies=[...])` do `server.py`, que
   protege o roteador **inteiro**, e re-apontei o mutante para lá. **Sobreviveu também.**

A segunda sobrevivência é que fecha o diagnóstico: **as duas bastam sozinhas.** Nenhuma mutação de
**ponto único** pode falsificar a propriedade.

### Como distinguir dos outros desfechos

Mutante sobrevivente tem mais de uma explicação, e elas pedem ações opostas:

| desfecho | como confirmar | o que fazer |
|---|---|---|
| **teste fraco** | remova a guarda e observe o comportamento **mudando** na mão | reforce o teste |
| **guarda mascarada / inalcançável** | a guarda nunca roda no caminho medido | conserte o call site |
| **guarda errada** | o mutante muda o comportamento e o **novo** é o correto | conserte a guarda |
| **equivalente por camada dupla** | remova UMA camada e meça: comportamento **idêntico**; remova a OUTRA: idêntico também | **remova o mutante do plano** e escreva o porquê |

🔑 **O teste de mesa:** antes de concluir "equivalente", **prove a segunda camada existindo** —
localize-a no código e cite arquivo e linha. Sem isso, "é equivalente" vira desculpa para
sobrevivente incômodo, que é exatamente o autoengano que a mutação existe para impedir.

### Por que REMOVER o mutante é o certo, e não deixá-lo no placar

Sobrevivente equivalente **infla o denominador**: `11/12` sugere cobertura faltando quando o que
existe é cobertura **dobrada**. A próxima pessoa lê o placar, procura o buraco e não acha — ou,
pior, "conserta" removendo uma das camadas para o mutante morrer.

Remova o mutante e **deixe o motivo escrito no lugar dele**, com as duas medições. O teste da
propriedade continua valendo: ele prova que quem não pode, não consegue — que é o que importa.

⚠️ **Cuidado com a âncora antes de tudo isto:** um mutante marcado como "sobrevivente" pode estar
só mal ancorado. Se a âncora casa mais de uma vez (por ser substring de outra linha, por exemplo),
um runner honesto marca **PODRE** em vez de "morto" — confira isso antes de teorizar sobre
equivalência. Ver [[script-de-mutacao-e-regua-afira-a-regua]].
