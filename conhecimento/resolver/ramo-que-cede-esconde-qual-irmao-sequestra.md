## O ramo que CEDE esconde qual irmão sequestra a mensagem {#ramo-que-cede-esconde-qual-irmao-sequestra}

`tags: roteamento, handler multi-ramo, fall-through, retorna None, defeito intermitente, hipotese errada, gate lexical, classificador, teste parametrizado, bot, chatops, dispatch`

**Contexto:** um handler tem vários ramos (`listar`, `pagar`, `cancelar`, `alterar`) escolhidos por um
classificador. Reportam que uma frase de OUTRO domínio é respondida errado por ele. A hipótese natural
— *"o gate lexical dele é largo demais, então ele engole toda essa família de frases"* — vira o plano
de conserto sem ninguém medir.

**Causa raiz:** os ramos **não se comportam igual**, e o que você testa primeiro é justamente o que
funciona. Um ramo costuma ter sido construído para **CEDER** — devolve `None` em zero-match, de
propósito, para a frase cair no fluxo genérico. Os irmãos devolvem `str` **sempre**, usando a mensagem
de erro do resolvedor de alvo. Resultado: a frase mais óbvia e mais natural (a que você digita primeiro
para "confirmar o bug") passa pelo ramo que cede e **chega no destino certo**. Você conclui "não
reproduz", ou pior, conserta o gate e mexe no raio de um handler que escreve sem precisar.

**Sinal de reconhecimento:** o defeito reportado usa um verbo/ação diferente do que você testou. Em
2026-08-23 o report era *"corrige o valor que paguei da dívida do X"* (→ ramo `alterar_valor`, que
SEMPRE responde) e o teste de confirmação usou *"paguei 300 da dívida do X"* (→ ramo `pagar`, que
cede). A segunda frase era, inclusive, a que a própria ajuda do produto ensinava — e já funcionava.

**Diagnóstico (a ordem que funciona):**
1. **Meça pelo pipeline real, nunca chamando o handler direto.** Pergunta de ROTEAMENTO respondida por
   sonda que pula o roteador mente: outro handler acima pode ver a frase antes.
2. **Parametrize o teste pela decisão do classificador**, não por uma frase. A garantia que interessa
   é *"frase do domínio X não é respondida pelo handler Y, diga o classificador o que disser"*.
   O ramo que passa verde **é informação**, não ruído: ele te diz onde o fall-through já existe.
3. Só então decida onde consertar.

**Conserto:** no **gate**, não em cada ramo — consertar ramo a ramo altera o fail-open de quem foi
desenhado para clarificar, e são N mudanças de comportamento em vez de uma. A guarda deve exigir
**âncora explícita + um sinal que o outro fluxo saiba atender**; com âncora e sem sinal, não ceda —
ceder ali é fechar uma porta sem abrir a outra, que é trocar de defeito.

**Corolário que morde depois: roteamento ≠ capacidade.** Consertado o destino, a frase pode chegar num
fluxo que **não sabe fazer aquilo**. No caso medido, corrigir um pagamento passou a cair no fluxo de
dívida — que só sabe *criar* pagamento, não corrigir — e só não escreveu errado porque a extração de
nome embaralhou o alvo. Depender de acidente é dívida, não conserto: registre como achado aberto em vez
de declarar resolvido.

**Por que sobreviveu tanto tempo:** a cobertura inteira do outro domínio chamava o handler **direto**
(10 casos ricos, nenhum passando pelo roteador). O vão entre dois handlers vizinhos é invisível para
cobertura que entra por dentro de cada um.

Ver também [[teste-que-nao-fecha-pode-acusar-capacidade-inalcancavel]].
