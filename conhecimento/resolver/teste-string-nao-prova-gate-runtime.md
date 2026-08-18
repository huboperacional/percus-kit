## Teste de presença/ausência de string não prova nada quando o gate é em RUNTIME sobre um template estático {#teste-string-nao-prova-gate-runtime}

`tags: template estático, feature flag, runtime gate, teste de comportamento vs presença de símbolo, JS servido, harness Node, string assertion`

**Contexto:** Paid Media Automation, sessão 2026-08-04/05 — toggle de client-side por plataforma no
loader de tracking (`_LOADER_TEMPLATE`, `services/tracking/app/modules/proxy/router.py`). O plano de
implementação rascunhou testes do tipo `assert "fbq('init',PIXEL_ID)" not in body` pra provar que,
com a flag desligada, o loader servido não instala o Pixel. Um subagente, seguindo TDD à risca,
escreveu o teste, rodou, e viu ele FALHAR mesmo contra uma implementação já correta.

**Causa raiz:** o design escolhido gateia a EXECUÇÃO (`if(PIXEL_ID&&FLAG){ fbq('init',...) }`), não a
PRESENÇA do texto — o corpo da função `fbq('init',...)` é parte do template estático e sai
IDÊNTICO no JS servido tanto com a flag ligada quanto desligada; só o `if` em volta muda de
resultado quando o navegador executa. Um `assert texto not in body` nunca vai conseguir diferenciar
os dois casos, porque o texto é o mesmo nos dois — o teste tal como rascunhado é logicamente
impossível de passar contra qualquer implementação correta que gateie por essa forma (`if(){...}`
em vez de omitir o trecho do template).

**Sinal de alerta pra generalizar:** qualquer feature flag/toggle implementada como `if(condição){
codigo_estatico }` dentro de um template/string que é gerado UMA VEZ e interpretado depois (JS
servido, SQL, template de e-mail, config gerada) tem essa armadilha. Se o plano/spec pede "o corpo
gerado NÃO deve conter X quando a flag está off", pare e confirme: a flag está omitindo X do
template, ou só envolvendo X num `if`? No segundo caso, teste de string está testando a coisa errada.

**Solução:** trocar o teste de "presença de símbolo" por teste de COMPORTAMENTO real — rodar o
artefato servido de verdade num interpretador real (aqui, harness Node mínimo: shim de
`window`/`document`/`dataLayer`, `subprocess.run(["node", tmp_file])`, inspeciona os efeitos
colaterais reais como `typeof window.fbq !== 'undefined'` ou o conteúdo do `dataLayer` capturado).
O subagente confirmou a causa raiz rodando o teste original (errado) contra uma implementação já
correta e vendo-o falhar por construção — prova de que o defeito era do teste, não do código —
antes de reescrever.

**Ref:** Paid Media Automation, `services/tracking/tests/test_loader_script.py`
(`_run_install_effects_harness`/`_run_pmatrack_ga4_harness`), commit `be557929`, sessão 2026-08-04/05.
