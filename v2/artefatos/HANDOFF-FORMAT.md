# Formato: `HANDOFF.md` — onde parei

**Dono de:** estado atual e próximo passo. **Teto: 150 linhas.**

**O que este arquivo NÃO é:** um log. Ele descreve o **presente**. O que virou passado sai para `docs/historico/`.

> ⚠️ Este formato existe por causa de um caso real: um `HANDOFF` que virou append-only chegou a **6.185 linhas** e passou a custar ~90k tokens por boot — com o agente lendo estado **truncado**, ou seja, potencialmente antigo. A forma abaixo **não tem onde empilhar histórico**. Isso é proposital.

---

## Estrutura (campos fixos — não acrescente seções)

```markdown
# HANDOFF — {projeto}

## Estado agora
{1 parágrafo. O que está de pé em produção, o que está em obra.}

## Próximo passo
{UMA ação, sem ambiguidade. Se há três candidatas, escolha a primeira e diga por quê.}

## Bloqueios
{O que impede de avançar — ou "nenhum".}

## Em obra
| Feature | Estado | O que falta |
|---|---|---|
| {nome} | `[2-E]` | {ação concreta} |

## Onde está o resto
- Plano e estados: `docs/PLANO.md`
- Vocabulário: `CONTEXT.md`
- Decisões: `docs/adrs/`
- Histórico: `docs/historico/`
```

## Regras

- **Só features fora de `[5-T]`** entram em "Em obra". Feature pronta vive no `PLANO`, não aqui.
- **Reescreva, não acrescente.** O campo "Estado agora" é substituído a cada checkpoint — não recebe parágrafo novo embaixo do anterior.
- **Sem seção de histórico.** Se sentir falta dela, o conteúdo é histórico: mova para `docs/historico/`.

## Teste do artefato

Abra e pergunte: *"se eu fechar tudo agora e voltar amanhã sem memória nenhuma, consigo retomar só com isto?"* Se a resposta é "talvez", falta **próximo passo concreto** — quase nunca falta histórico.
