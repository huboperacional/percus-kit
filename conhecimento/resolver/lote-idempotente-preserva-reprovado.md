## Diretório de saída de lote idempotente preserva o REPROVADO e o entrega como aprovado {#lote-idempotente-preserva-reprovado}

`tags: lote, batch, idempotente, idempotencia, skip se existe, gate, aprovado, reprovado, quarentena, api paga, custo, processo concorrente, ps -ef, scratchpad, md5, contagem`

**Sintoma:** um lote idempotente ("pula o que já existe") é retomado a partir de um diretório que a documentação descreve como "só os aprovados". Ele roda, completa, e o resultado entra em produção **contendo itens que um gate já havia reprovado** — sem erro, sem log, sem nada a estranhar.

**Causa raiz:** duas premissas que se combinam mal.
1. `[ -f "$alvo" ] && continue` trata **"existe"** como **"está bom"**. A idempotência protege contra gasto duplicado; ela **não** sabe distinguir saída boa de saída ruim.
2. O diretório de saída **acumula**: reprovado que ninguém apagou continua lá. Quem escreveu "já apaguei os reprovados" no handoff apagou da **cópia curada**, não do diretório de trabalho — e as duas divergiram em silêncio.

**Solução:**
- **Rode o gate ANTES de gastar** a chamada cara. Se o gate for local e barato (medida sobre arquivo, checksum, lint), medir o que já existe custa segundos e diz exatamente o que aproveitar. Isso inverte a ordem usual (gerar → medir) e é o que impede pagar de novo pelo que presta e entregar o que não presta.
- **Reconstrua o diretório de entrada a partir da fonte curada, comparando por NOME e HASH — nunca por contagem.** Contagem esconde troca (um a mais e um a menos fecha a conta) e é onde o olho erra: `diff <(ls -1 A | sort) <(ls -1 B | sort)` e `md5sum` decidem.
- **Quarentene, não apague**, o que reprovar — mover para `saida-reprovado/` deixa o lote regerar e preserva a evidência de por que reprovou.
- **Confira também os INSUMOS** (a base/entrada de onde a saída deriva). Se o insumo divergir entre as cópias, o que já estava aprovado passa a ser medido contra outro insumo e **reprova falsamente** — e a leitura vira "o pipeline quebrou", mandando debugar o que está são.

🔴 **Antes de disparar lote caro, `ps -ef | grep` pelo script.** Havia um segundo lote da sessão anterior ainda rodando, gravando **no mesmo diretório** e consumindo a mesma API em paralelo. O sinal foi indireto: arquivos aparecendo **fora da ordem** do meu script, e `.tmp` órfãos de dois PIDs. **O segundo processo é invisível no log do primeiro**, e cada um cobra. Sessão encerrada (`/clear`) não mata processo que ela disparou em background.

**Quando o gate reprova, regere o item culpado, não o grupo inteiro.** O grupo costuma ser a unidade do **veredito** (só o conjunto revela a inconsistência), mas raramente é a unidade do **conserto**: identificar qual item está fora e regerar só ele fecha o grupo por uma fração do custo.

**Ref:** AutoWorx, 2026-08-15 — lote de 45 renders com gate de rampa. O diretório dito "21 aprovados" tinha **38 arquivos**, 17 deles reprovados. Memória `reference_lote_dir_nao_e_o_conjunto_aprovado`. Relacionado: `#alvo-do-spec-stale` (handoff descrevendo estado que não é o real).
