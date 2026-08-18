## Review por-task em `subagent-driven-development` não pega bug que veio do próprio texto do plano {#review-por-task-nao-pega-bug-do-plano}

tags: subagent driven development missing bug, plan code has defect, per-task review insufficient, spec requirement unimplemented, whole branch review finds gap, multi-task plan hidden bug, RF requirement missed by every task reviewer

**Sintoma:** um plano multi-task (8 tasks) executado via `superpowers:subagent-driven-development`
teve TODAS as tasks aprovadas "Ready to merge: Yes" individualmente (implementer + spec-reviewer +
code-reviewer por task, alguns com 2-3 rodadas de fix reais) — mas, ao rodar o passo final da
skill ("dispatch final code reviewer subagent for entire implementation" contra o diff acumulado
inteiro e a spec completa), apareceram 2 achados reais que NENHUM review por-task tinha pego: um
requisito EARS "DEVE SEMPRE" (RF-05) 100% não implementado, e uma exigência de transação explícita
da spec (§3.4) ignorada.

**Causa raiz:** cada task individual foi implementada **exatamente como o próprio texto do plano
prescrevia** — o código da task bateu com o código proposto pelo plano, e o spec-reviewer de cada
task confere "implementação bate com ESTA task", não "implementação bate com a spec INTEIRA".
Quando o BUG está no próprio texto do plano (o autor do plano esqueceu de implementar um requisito,
ou implementou parcialmente), review por-task estrutural nunca detecta — porque não existe
"desvio" nenhum entre task e implementação, o desvio é entre plano e spec. Só um review que lê a
spec completa E o diff acumulado INTEIRO de uma vez consegue notar "RF-05 existe na spec, cadê no
código?" — pergunta que nenhum reviewer de task individual está posicionado pra fazer.

**Solução:** nunca pular o passo final da skill (`dispatch final code reviewer subagent for entire
implementation`) mesmo quando toda task individual já fechou "Ready to merge: Yes" — é
especificamente esse passo, com escopo = spec completa + diff acumulado inteiro, que pega bugs
oriundos do PRÓPRIO PLANO (não do implementer). Ao montar o prompt desse review final, force o
reviewer a andar pela lista de requisitos (RF-01, RF-02, ... um por um, "satisfeito/gap/N-A" com
evidência) em vez de só pedir "revise o diff" — revisão RF-a-RF é o que expõe requisito
inteiramente ausente, que uma leitura solta do diff tende a não notar (não hunta por AUSÊNCIA, só
por presença de código ruim).

**Ref:** Paid Media Automation, sessão 2026-08-09 — frente "Revisão Estruturada de Nomenclatura"
(8 tasks + 2 fixes). Ver memória local `project_nomenclatura_revisao_estruturada`.
