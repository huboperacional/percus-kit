## Sabotagem que outra guarda absorve NUNCA fica vermelha — a lista de nove pode conter uma guarda impossível {#sabotagem-que-outra-guarda-absorve-nunca-fica-vermelha}

`tags: sabotagem, guarda, teste, falso rigor, prova, tabela de sabotagens, redundancia, defesa em profundidade, invariante, R23`

**Sintoma:** o plano traz uma tabela de sabotagens — uma por regra, cada uma com o caso que deve
ficar vermelho quando aquela regra cai. Você sabota uma delas e **nenhum teste falha**. A leitura
natural é *"o caso não é aplicável"* ou *"o teste é fraco"*, e a linha vira um `N/A` na planilha.

**Causa raiz:** **duas regras vizinhas se sobrepõem, e uma absorve o efeito observável da outra.**
A sabotagem não é fraca — é **matematicamente impossível de ficar vermelha**.

Caso real (Empresa Milionária, fatia da cascata, 08/09/2026). O motor tinha duas regras coladas:

```python
novoInicio = max(novoInicio, etapa.inicioPrevisto)   # regra 1 — o "piso"
if novoInicio <= etapa.inicioPrevisto:               # regra 3 — parada antecipada
    return
```

A tabela mandava sabotar o piso e esperar que uma etapa fosse puxada para antes da data combinada.
Com `p = próximo dia útil` e `i = inicioPrevisto`:

| | `p <= i` | `p > i` |
|---|---|---|
| **com piso** | `max(p,i) = i` → a parada dispara (`i <= i`) → `return` | `max = p` → não dispara |
| **sem piso** | `p <= i` → a parada dispara → `return` | segue com `p` |

Idêntico nos dois ramos. Enquanto a parada antecipada existisse, **o `max` do piso nunca mudava o
comportamento** — e a linha da tabela prometia uma prova que não podia existir.

**O que torna isso pior que uma guarda ausente:** a tabela existe **precisamente** para garantir que
toda regra tenha um caso que a mata. Uma linha incapaz de falhar é **confiança fabricada com a
aparência exata do rigor** — e alguém conta com ela. É a irmã do `xfail` que falha pelo motivo
errado e do `assert` por faixa: critério que parece medir e não discrimina.

**Como resolver:**

1. **Execute toda linha da tabela ao menos uma vez.** Escrever não basta. **`N/A` é resposta
   proibida** — quando a sabotagem não derruba nada, isso é **achado**, não detalhe.
2. **Suspeite antes de rodar quando duas regras usam o MESMO referencial.** No caso acima, as duas
   comparavam contra `inicioPrevisto`; é aí que a sobreposição costuma estar.
3. **Não remova a regra redundante por reflexo.** Se ela é defesa em profundidade — vale quando a
   vizinha for estreitada um dia —, ela fica, **com a razão escrita junto do código**. Redundância
   declarada sobrevive à próxima refatoração; redundância silenciosa é apagada por quem passar.
4. **Troque a sabotagem por uma COMPOSTA e a guarda por um INVARIANTE.** Derrube as duas regras
   juntas, e asserte a propriedade que nenhuma delas pode violar sozinha (ali: *"nenhuma linha do
   plano tem início anterior ao que já estava combinado"*). O invariante discrimina onde o caso
   pontual não discriminava.
5. ⚠️ **O invariante precisa de cenário não vazio.** Asserido sobre lista vazia, ele passa
   trivialmente. E a trava de não-vacuidade **não pode ser igualdade exata** (`len(x) == 1`): se a
   sabotagem faz a coleção **crescer**, a igualdade falha pelo motivo errado e **esconde** a
   violação real. Use `>= 1`.

**Variante: o CORPO do teste é a guarda que absorve (Empresa Milionária, 2026-09-15).** Harness de
isolamento multi-tenant: o ataque manda um corpo "legítimo" à rota de outra empresa e aceita qualquer 4xx
como recusa. O plano prescrevia, para as confirmações de atalho, o corpo `{"esperado": []}` — que a regra de
negócio recusa com **409 de prévia envelhecida** antes de a checagem de empresa importar. Contraprova medida:
removido o filtro de empresa, o ataque seguiu **verde** (`1 passed`). A recusa vinha da regra de negócio, não
do isolamento. Correção: um corpo que a regra de negócio **aceitaria** na empresa certa (células vazias que
batem com o estado real), para que só o isolamento possa recusá-lo — com ele, a mesma sabotagem ficou
vermelha. Onde nenhum corpo passa pela regra (a origem vazia sempre dá 422), o 404 exato vai para um teste
dedicado que asserte o `detail`, nunca a faixa 4xx. Regra: **o corpo de um ataque tem de ser válido para
tudo MENOS a guarda atacada**, e isso se prova derrubando a guarda com esse corpo.

**Custo de ignorar:** a lista de sabotagens continua afirmando cobertura que não existe, e a regra
que ela deveria proteger pode ser removida numa "simplificação" sem nenhum teste ficar vermelho.
