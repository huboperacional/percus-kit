## Caminho que pula o interruptor pula também a configuração — e a falta de chave vira revogação da integração {#caminho-que-pula-o-interruptor-pula-a-configuracao-e-dispara-a-revogacao}

`tags: interruptor, feature flag, configuracao, chave de cifra, credencial, OAuth, revogacao, integracao, Google Drive, FR-399, disponibilidade, fail-closed, destrutivo, R23`

**Sintoma:** uma operação que o requisito manda funcionar "com a integração desligada" (ver, desconectar, exportar) apaga
ou revoga algo quando a **configuração** está ausente ou quebrada — ou estoura 500.

**Causa:** o requisito diz "funciona com o interruptor desligado", e a implementação simplesmente não chama a checagem de
disponibilidade. Mas essa checagem cobre duas coisas — **configuração** e **interruptor** —, e pular a função pula as duas.
Sem configuração, a chave que decifra a credencial não existe; o caminho seguinte trata "versão sem chave" como credencial
perdida e **revoga a integração** (comportamento certo para chave rotacionada e esquecida, desastroso para variável de
ambiente vazia num deploy).

**Caso concreto, medido em 16/09/2026 (Empresa Milionária, guarda do documento, Task 13):** abrir o documento guardado com
`GUARDA_CHAVE_CIFRA_ATUAL` vazia → `503 credencial_revogada` e a conexão da empresa com o Google Drive **revogada**; com a
chave mal formada, 500. Guardar não tinha o defeito: confere a disponibilidade inteira antes.

**Conserto:** separar as duas perguntas. A operação que ignora o interruptor ainda confere a **configuração** antes de
qualquer caminho que use a chave — e responde 503 "não configurada" sem tocar no estado. Se a função de disponibilidade
confere configuração antes do interruptor, basta testar `motivo == "nao_configurada"` (e não `motivo is not None`).

**Testes que pegam:** configuração quebrada (chave vazia, mal formada, chave anterior mal formada) × interruptor ligado e
desligado → 503 nomeando, nenhuma chamada ao provedor, integração intacta. Sabotagem nos dois sentidos: sem a checagem, a
integração é revogada; checando qualquer indisponibilidade, o teste de "funciona desligado" fica vermelho.
