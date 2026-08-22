## O teste que IMITA o produtor em vez de chamá-lo não amarra nada — e é a defesa que você achou que tinha {#teste-que-imita-o-produtor-nao-amarra-nada}

`tags: teste, produtor real, amarracao, fixture, guarda inerte, formato, falso verde, mutacao, cross-arquivo, review, contrato implicito`

**Sintoma:** você escreve um detector/parser que depende do **formato** produzido por outra função,
e escreve o teste que "amarra os dois" para que mudar o produtor derrube o teste. Meses depois o
produtor muda uma vírgula, o detector emudece em produção, e **o teste continua verde**.

**Causa raiz:** o teste **replicou** a f-string do produtor em vez de **chamar** o produtor. Ele
parece uma amarração — tem o nome, tem o comentário, tem o assert com o literal certo — mas o que
ele exercita é uma **cópia** do formato, congelada no momento em que você escreveu. Duas fontes de
verdade que ninguém compara. É a família *"guarda inerte porque o DADO mudou"*, com o agravante de
morar **dentro do teste escrito para preveni-la**.

**Por que a leitura não pega:** o teste é *bonito*. Ele importa algo do módulo de produção (no caso
real, o formatador de moeda), tem um assert de sanidade contra o texto real do banco, e passa. A
palavra "PRODUTOR" está no nome da função de teste. Tudo aponta para uma amarração que não existe.

**O caso (tiatendo, frente N27, 2026-08-21):** um detector precisava reconhecer o eco do readback de
carrinho do próprio bot. A assinatura era a tipografia do produtor — `×` (U+00D7) e `—` (U+2014),
que nenhum teclado de celular produz. A spec escreveu, na seção de riscos: *"o detector e
`_summaryLines` ficam amarrados por um teste que monta a linha pelo produtor real — se o formato
mudar, o teste cai junto"*. O teste entregue fazia:

```python
linha = f"{qty}× {name} — {_brl(price_cents * qty)}"   # <- IMITAÇÃO
assert linha == "1× Pizza Grande — R$ 0,01"
```

Importava `_brl` (do produtor) e por isso *parecia* amarrado. Mas a f-string era uma segunda cópia:
trocar `—` por `-` dentro de `_summaryLines` deixaria o teste **verde** e o detector **cego**.
Quem pegou foi a review cross-provider, não a leitura humana nem a suíte.

**O conserto — e ele tem duas metades, não uma:**

1. **Chame o produtor de verdade**, com o I/O mockado (não o formato mockado). No caso: mockar
   `listByOrder` e `_activeMenu` e chamar `_summaryLines`, deixando a f-string ser exercida.
2. 🔑 **Prove a amarração com um alvo de mutação em OUTRO ARQUIVO.** Esta é a metade que falta em
   quase toda correção deste tipo: mute o **produtor** (troque o `—` por `-` em `_summaryLines`) e
   exija que o teste **do consumidor** fique vermelho. Sem esse alvo, "agora está amarrado" é
   promessa; com ele, é medição.

**Como achar na sua base:** procure teste cujo nome ou comentário promete amarração/contrato de
formato e verifique se o corpo **chama** a função que produz o formato. Regra prática: se o teste
contém uma f-string ou um literal que **espelha** a do código de produção, ele não amarra — ele
duplica. Pergunta que resolve em um minuto: *"se eu mudar só o produtor, este teste cai?"* Se você
não consegue responder sem ler o produtor, escreva o alvo de mutação e descubra.

**Relacionado:** [[fixture-que-mente-faz-a-mutacao-mentir-junto]] (a fixture inventa a forma; aqui o
TESTE inventa a forma) · [[mutacao-que-nao-casa-finge-que-o-gate-nao-reprova]] · a família
*"guarda medida funcionando fica INERTE quando o DADO muda"*.
