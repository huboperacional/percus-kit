## `xfail(strict)` que nunca libera é guarda impossível — prove os DOIS lados {#xfail-strict-que-nunca-libera-e-guarda-impossivel}

`tags: pytest, xfail, strict, XPASS, guarda impossivel, sabotagem, prova de liberacao, teste vacuo, defeito conhecido, divida marcada, regex, placeholder`

**Sintoma:** um `xfail(strict=True)` registra um defeito conhecido e parece saudável — falha hoje,
pelo motivo certo, e a suíte segue verde. Só que **nenhuma correção o faz passar**. No dia do
conserto o teste continua vermelho, a suíte não volta ao verde, e a próxima sessão apaga o marcador
achando que é ruído.

**A assimetria que engana:** a sabotagem habitual pergunta *"a guarda fica vermelha quando o defeito
volta?"* — e ela **passa**, porque o teste já estava vermelho **pelo motivo errado**. O verde falso
está do outro lado, e ninguém olha para lá.

**Caso medido (Empresa Milionária, 2026-08-24).** Guarda da voz do bot. Dois testes do mesmo arquivo:

- o padrão de persona proibia o placeholder `{nomeFamilia}` no prompt;
- a trava de regressão ao lado exigia que a chave **continuasse** se chamando `nomeFamilia`, porque
  é isso que o call site passa em `.format()`.

Os dois não podiam ficar verdes juntos. Depois de corrigido, ainda faltava um `\b`: o padrão
`fam[íi]lias?` casava **"Familia" dentro de `{nomeFamilia}`** e a guarda voltava a ser impossível
pela porta dos fundos. O mesmo teste de liberação pegou de novo.

**O método — duas provas, sempre:**

1. **Falha hoje**, contra o defeito real.
2. 🔑 **Passa quando corrigido:** substitua o alvo por uma versão **plausivelmente correta** — em
   memória, via plugin de sessão do pytest (`-p meu_conftest`) — e exija **XPASS em todos os
   marcadores**. Restaure em `finally`.

```python
# plugin de sessao: troca o alvo ANTES da coleta
import app.modules.ai.service as s
s.CHAT_SYSTEM_PROMPT = PROMPT_JA_CORRIGIDO
```

Se algum marcador continuar `XFAIL`, a guarda é impossível e precisa mudar **antes** de ser
commitada.

**Terceira prova, quando a guarda varre texto de voz/marca:** que ela **não reprove redação
legítima**. `\bfamília\b` barra *"não misture as finanças da família dos sócios com o caixa da
empresa"* — conselho correto a uma PME. Uma guarda assim não é imprecisa: ela **trava a reescrita
que existe para cobrar**, e quem escrever vai desligá-la.

🪤 **Não copie o padrão de outra guarda sem medir contra o alvo atual.** O padrão das páginas
públicas exigia substantivo financeiro antes de "da família"; o prompt dizia *"assistente
**financeira** … da família"* — adjetivo. Adotá-lo tal qual faria o `xfail` virar XPASS na hora e
derrubaria a suíte pelo `strict`.

**Saída elegante quando o identificador atrapalha:** use o placeholder como **âncora de contexto**,
não como proibição. `da família {nomeFamilia}` casa o vazamento e libera assim que a reescrita
disser `da empresa {nomeFamilia}`, com a chave intacta.

Complementa [[xfail-que-xpassa-anuncia-defeito-que-nao-demonstra]] pelo lado oposto: lá o `xfail`
**sempre** xpassa e deve ser removido; aqui ele **nunca** xpassa e deve ser corrigido. Ver também
[[a-sabotagem-prova-o-que-voce-imaginou]].
