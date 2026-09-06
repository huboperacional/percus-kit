## Suíte inteira PULADA sai com código `0` e é lida como verde — o marcador condicional apaga a medição de quem queria medir {#suite-pulada-sai-zero-e-e-lida-como-verde}

tags: pytest, skip, skipif, marcador, exit code, medicao, controle positivo, janela cara, R20, verificacao, gate, R23

**Sintoma.** Você roda a suíte que só existe para provar uma coisa cara — testes contra banco
real, contra ambiente efêmero, contra infra que alguém autorizou item a item — e o comando
responde:

```
8 skipped, 1 warning in 0.15s
```

**com exit code `0`**. Nenhum erro, nenhum vermelho, nenhum aviso. Quem lê o código de saída, ou
quem só olha "o comando passou", registra a prova como feita. **Nada foi medido.**

**Por que morde, e por que é pior que os outros zeros.** Aqui não há pipeline quebrado, filtro
escondendo erro, nem default do shell preenchendo um número. **O framework está funcionando
exatamente como projetado.** O `skipif` do módulo é a MESMA linha que protege a suíte local de
quem não tem o banco — e que apaga a medição de quem tem. As duas situações produzem saída
idêntica:

```python
pytestmark = [
    pytest.mark.postgres,
    pytest.mark.skipif(not os.environ.get("PG_TEST_URL"), reason="defina PG_TEST_URL"),
]
```

Esquecer o `export` no shell certo, rodar de um `cwd` que não carregou o `.env`, ou perder a
variável ao entrar num contêiner — todos dão `N skipped` e `0`.

🔴 **O custo é assimétrico e é isso que separa este verbete do genérico.** Esse tipo de suíte
costuma rodar dentro de uma janela que **custa infra e autorização** (R20): container efêmero na
VPS, credencial temporária, tempo do operador. Um "verde" ali não é relido depois — ele vira a
marca `[5-T]` de um requisito, e a janela fecha. Nos outros zeros você perde um achado; aqui
você perde a janela **e** fica acreditando que a prova aconteceu.

**Como resolver.** Guarda de intenção **na MESMA chamada**, antes do runner:

```bash
[ -n "$PG_TEST_URL" ] || { echo "PG_TEST_URL VAZIA: a medicao seria N skipped e sairia 0"; exit 1; }
python -m pytest -m postgres -q
```

E a regra de leitura, que é a parte generalizável: **o placar se lê em `N passed`, nunca em "o
comando saiu 0"**. Todo marcador condicional — `skipif`, `-m`, `-k`, `xfail` — converte "não
medi" em exit `0`, que é indistinguível de "medi e passou".

⚠️ **Antes de escrever no runbook que "sem a variável dá N skipped", RODE.** No caso que gerou
este verbete a frase foi escrita a partir da leitura do `skipif` e só depois medida; estava certa
por sorte. **Afirmação sobre a medição é tão fácil de escrever errada quanto a medição em si**, e
o cabeçalho de um runbook é lido pela próxima sessão como se fosse dado medido.

**Sinal barato de que você está exposto:** qualquer suíte cujo `pytestmark` dependa de variável
de ambiente e que só rode em janela autorizada. Rode-a **uma vez sem a variável, de propósito**,
e confira que o resultado é indistinguível do sucesso. Se for, a guarda é obrigatória.

Irmão geral: [[zero-so-vale-como-prova-com-controle-positivo]] — lá o probe está cego; aqui o
probe nem chegou a existir, e o runner declara sucesso por isso.
