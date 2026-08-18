## Guard CERTO sem caminho alternativo produz o OPOSTO do que protege {#guard-sem-caminho-alternativo}

`tags: guard, guarda, except Exception, or vazio, fallback, degradar pro neutro, ausencia de prova, prova de ausencia, fail-open, fail-closed, lado da falha, par assimetrico, acao destrutiva, pausa, blip de banco, classe de defeito, varredura`

**Sintoma:** um guard revisado, aprovado e **correto no caso previsto** é a causa do pior estrago do
sistema — e a fala/ação dele é a mais errada possível **sobre justamente o domínio que ele protege**.

**A forma abstrata:** guard correto no caso previsto cuja reação ao caso **NÃO previsto** (`except`,
`else`, `or []`, `None`) produz o **OPOSTO** do que ele protege, em vez de **degradar pro neutro**.
Quase sempre: **ausência de prova tratada como prova de ausência**.

**Casos medidos (tiatendo — 4 reincidências só em 2026-07-31):**
- Guard que impede o LLM de inventar dinheiro, **sem** caminho determinístico para "quanto fica meu
  pedido?" → respondia *"seu pedido ainda não foi fechado"* a quem perguntou o total.
- Guard que apaga o refresh cookie quando o auth diz que a sessão morreu; `None` também acontecia em
  **timeout** → destruía sessão de 30 dias **viva**.
- **Forma nova, a mais cara:** falha de leitura das zonas de entrega (`except` tratado igual a "zero
  linhas", com `or []`) fazia o bot **afirmar** *"esse endereço está fora da minha área de entrega"*,
  **pausar o bot** e **limpar o checkout**. O mesmo era dito quando o bot simplesmente **não entendeu
  a frase**. Ou seja: *o guard produziu a afirmação factual mais errada possível sobre a própria área
  de cobertura* — e ainda executou o destrutivo em cima dela.

**Como achar (greps que rendem, em ordem de retorno):**
1. **`except Exception`** — o de maior retorno. Leia o que vem **depois**, não o log.
2. `or []` / `or {}` / `?? []` colado em leitura de banco/API — "não consegui ler" virando "não
   existe".
3. Cliente de API que devolve `None`/`null` no erro e é usado como **valor de negócio**.
4. Toda **ação destrutiva ou irreversível** (pausar, limpar, apagar, cobrar, cancelar, banir) — e
   **suba** dali: quem chega aqui com dado incompleto?
5. **Par assimétrico:** um `if` que trata como um só dois casos de custo oposto ("não atendemos ali"
   × "não deu pra saber"). Esses dois precisam de ramos diferentes, sempre.
6. **O NOME do teste:** um teste chamado `..._cai_no_fallback` costuma **cimentar** o defeito em vez
   de proteger — cf. [#teste-passa-em-cima-do-defeito].

**Solução:**
- **Separe os casos:** "zero linhas" ≠ "exceção". Só o primeiro autoriza o fallback.
- No caso não previsto, **degrade pro neutro**: perguntar, repetir, escalar — e **nunca** executar o
  destrutivo nem **afirmar** fato sobre o domínio.
- **Escreva no código o lado para o qual o guard falha** e o custo aceito. Sem isso, o próximo leitor
  "conserta" o que era deliberado.
- Achou um, **varra a classe**: o padrão vem em cacho (uma varredura rendeu 5 de uma vez).

**Ref:** tiatendo — catálogo em
`D:\Claud Automations\tiatendo\docs\auditoria-guard-sem-caminho-alternativo-2026-07-29.md`, verbete
em `D:\Claud Automations\tiatendo\CONTEXT.md`; commits `5c8363f` (5 guards de uma vez), `4039f7a` e
`4f369ca` (zonas de entrega). Irmãos: [#guarda-destrutiva-testar-com-perguntas],
[#fail-open-esconde-teste-vacuo], [#guarda-redundante-tesoura-ou-morta],
[#degrade-gracioso-esconde-noauth], [#provider-none-vira-entrega], [#gate-confirmacao-dead-end].
