## Esconder uma opção do `<select>` sem tirar o form: o navegador escolhe a primeira por você — e grava {#esconder-opcao-do-select-sem-tirar-o-form}

`tags: select, option, selected, formulario, allowlist, estreitar opcoes, modo legado, perda silenciosa de dado, painel admin, jinja, template, valor default do browser, deprecar opcao`

**Origem:** tiatendo, 2026-08-21 — achado pela review cross-provider **dentro da própria frente que
existia para evitar esse dano**.

Uma opção de configuração (`print`/`both`) parou de ser oferecida porque não entregava o que
prometia. O template passou a percorrer só a lista curta:

```jinja
<select name="value">
  {% for m in modos_oferecidos %}{# off, screen #}
    <option value="{{ m }}" {% if m == atual %}selected{% endif %}>{{ m }}</option>
  {% endfor %}
</select>
<button type="submit">Aplicar</button>
```

Para o registro que ainda estava em `both`, **nenhuma `<option>` recebe `selected`** — e aí não é o
seu código que decide: **o navegador envia a primeira opção da lista**. Um clique em "Aplicar", sem
ninguém tocar no select, gravava `off` e **desligava um recurso que estava funcionando**. O dano é
exatamente o que a mudança queria impedir.

- **Por que passa despercebido:** a tela *parece* certa (mostra só o que você quer oferecer), o
  teste de rota *passa* (ele posta um valor explícito), e o allowlist do servidor *aceita* `off`,
  porque `off` é legítimo. Não há erro em lugar nenhum — só um estado que muda sozinho.
- **Avisar não resolve.** Um texto "modo atual: `both` — legado" explica a leitura e **não impede a
  ação**. O botão continua ali.
- **O conserto:** se o valor atual não está entre os oferecidos, **não renderize o form** — só o
  texto. Sem "Aplicar", não há gravação acidental; quem quiser mudar de verdade edita a fonte.
  (A alternativa `<option selected disabled>` é pior: opção desabilitada não é submetida, e você
  volta ao mesmo sorteio.)
- **A regra geral:** ao ESTREITAR a lista de opções de um form, o registro fora da nova lista vira
  um caso de borda que **escreve**. Trate "não posso mais oferecer" como "não posso mais aceitar
  submissão daqui", não como "vou mostrar menos itens".
- **Prova barata:** mutação no template (`{% if atual in oferecidos %}` → `{% if True %}`) tem que
  derrubar um teste que renderiza a tela com o valor legado e procura o form. Sem esse teste, a
  correção é promessa.

**Irmão:** `ofertar-nao-e-aceitar-estreite-a-escrita-nao-a-leitura.md` — a outra metade da mesma
decisão (a leitura do valor legado **não** pode encolher junto, senão o registro vivo vira default
no primeiro reload).
