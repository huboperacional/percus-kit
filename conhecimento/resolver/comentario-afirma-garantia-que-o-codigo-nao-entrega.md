## Comentário afirmando garantia que o código não entrega — a classe de bug mais difícil de ver {#comentario-afirma-garantia-que-o-codigo-nao-entrega}

`tags: comentario mentiroso, doc drift, review, amortizado, guard que nao guarda, codigo morto, especificidade CSS, Number(null)`

**Sintoma:** o código tem um comentário explicando por que ele é seguro/correto, e a explicação é **falsa**. Como o comentário parece cuidadoso e específico, ele desliga a suspeita de quem lê — inclusive a de quem o escreveu.

**Frequência medida:** **quatro vezes numa única sessão** (2026-08-18), todas em código meu, todas pegas por review cross-provider e nenhuma por leitura própria:

1. *"a poda roda só quando o mapa encosta no teto, então o custo é amortizado"* — a poda parava **exatamente** no teto, então o próximo item disparava varredura completa de novo. Não era amortizado.
2. *"o que limita o caso desonesto é o rate limit acima"* — o rate limit conta **tentativas**, não **bytes**; as 5 primeiras passavam com o corpo que viesse.
3. *"leitura interrompida vira corpo inválido"* — o código devolvia o mesmo valor para "estourou o teto" e "stream morreu", e o chamador respondia 413 nos dois.
4. *"`.admin-input` e a utility têm especificidade igual, quem vence é a ordem de carregamento"* — `.admin-theme .admin-input` é **0,2,0** e utility é **0,1,0**: a utility perde SEMPRE. O `rounded-full` ao lado era código morto.

🔑 **O padrão que une os quatro:** o comentário descreve a **intenção** no momento em que foi escrito, e sobrevive intacto quando o código ao redor muda — ou quando a intenção nunca chegou a ser implementada. Ele não é verificado por nada: nem compilador, nem teste, nem lint.

**Solução — transformar a afirmação em asserção:**
- Todo comentário que afirma uma **propriedade** (amortizado, limitado, ignorado, sempre/nunca) deve ter um teste com esse nome. Se a propriedade não é testável como está escrita, ela provavelmente não é verdadeira como está escrita.
- Em review, ler o comentário como se fosse uma **claim a refutar**, não como contexto. Foi assim que os quatro caíram.
- Ao mudar código, reler o comentário **acima e abaixo** do trecho: o drift entra por vizinhança.

⚠️ Vale igual para comentário sobre dado externo. No mesmo dia, um comentário afirmava que o slot de vídeo editava `youtubeId` — verdade quando foi escrito, falsa desde a migração para mp4 duas semanas antes. Quem confiasse nele portaria o campo errado.
