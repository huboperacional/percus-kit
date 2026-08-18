## O fix vira o defeito seguinte: 3 CRITICALs em 5 rodadas, cada um filho da correção anterior {#fix-vira-defeito-seguinte}

`tags: review, CRITICAL em cascata, fix vira defeito, remedio generico, COALESCE, dupla escrita, intencao vs valor, credencial revogada, espelho stale, rodadas de revisao`

**Sintoma:** cada rodada de review acha um CRITICAL, você corrige, a rodada seguinte acha outro
CRITICAL **na sua correção**. Três das cinco vezes seguidas. Parece azar ou revisor implicante; não é.

**Causa raiz:** você está aplicando um **remédio genérico sobre o VALOR** a um problema que pede a
informação de **INTENÇÃO**. No caso real (dupla escrita de credenciais de tracking): "nunca escreva
NULL" virou `COALESCE(:v, coluna)` → isso trocou *apagar credencial* por *par incoerente* (id de um
registro com segredo de outro) **e** tornou impossível limpar qualquer campo; "então não copie nada"
→ isso deixou o espelho velho e **ressuscitou credencial revogada** no toque seguinte. Copiar tudo e
copiar nada são os dois extremos de um eixo em que a resposta certa não está.

**Solução:** parar de decidir pelo valor e passar a decidir pelo que o usuário **pediu**. Concretamente:
levar o conjunto de campos efetivamente enviados (`payload.model_dump(exclude_unset=True)` no
pydantic) **até a camada de dados**, e copiar exatamente esse subconjunto. Junto:
- parâmetro **kw-only SEM default** quando o mesmo valor significa coisas opostas em dois chamadores
  (ali, "coluna vazia" era *"o operador desconectou"* numa rota e *"não há o que espelhar"* na outra) —
  o call site esquecido quebra no import em vez de escolher em silêncio;
- e **executar contra o banco real**: os 4 primeiros remédios foram raciocínio sobre o código; o que
  encerrou o ciclo foi rodar o código real contra Postgres real, com os dois extremos virando dois
  testes que se contradizem se alguém mexer num só.

**Como perceber cedo:** se a sua correção é uma regra sobre *que valor escrever* (`COALESCE`,
"nunca NULL", "sempre copia", "nunca copia"), pergunte se o dado que falta é **a intenção de quem
chamou**. Se for, nenhuma regra sobre o valor vai fechar.

**Ref:** Paid Media Automation, fatia 1 de multiplicidade de destinos (2026-07-26), commit `6c1b635`.
