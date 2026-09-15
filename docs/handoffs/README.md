# docs/handoffs/ — handoffs de release cross-repo (registro histórico)

> **⚠️ Registros point-in-time, NÃO estado atual.** Fonte da verdade vigente: `CANON_VERSION.md`.

Handoffs aqui são passos-a-passo que o canon **entrega ao operador** para aplicar manualmente em outro
repo (Painel, consumidores) numa release específica — o canon nunca escreve cross-repo (protocolo:
caixa de texto pro operador colar). Ver `conhecimento/resolver/cross-repo-write.md`.

| Doc | Release | Estado |
|---|---|---|
| `HANDOFF_PAINEL_v6.10.md` | v6.10.0 (re-alocação de portas, bloco de 20) | Aplicado — histórico |
| `HANDOFF_CONSUMIDORES_v6.10.md` | v6.10.0 (re-alocar `port_base` em cada projeto) | Aplicado — histórico |
| `HANDOFF_CONSUMIDORES_v6.56.md` | v6.56.1 (R11 com retry + `registrar-review`; hook lê o marcador) | Em curso — hooks git reinstalados nesta máquina em 2026-09-15; 4 `CLAUDE.md` aguardam commit no próprio projeto |

Handoffs de releases passadas ficam como referência de "o que foi pedido ao operador naquela versão".
Não são instrução corrente — para o estado atual de portas/infra, ver `02_INFRA` §5 + R22.
