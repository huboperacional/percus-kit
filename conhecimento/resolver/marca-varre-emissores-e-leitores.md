## Marcar uma entidade como "fora do padrão": filtre os EMISSORES, não só os leitores {#marca-varre-emissores-e-leitores}

`tags: flag, marcar entidade, fora do padrao, conversa administrativa, tenant de teste, leitores, emissores, broadcast, reengajamento, varredura dupla, medir no banco, silenciar sem devolver, horario comercial`

Ao criar uma flag do tipo "esta linha não é do tipo normal" (conversa administrativa, usuário
interno, tenant de teste, conta de sistema), a varredura óbvia é a dos **leitores**: métricas,
relatórios, boards, exports. Foi o que fiz — e fechei a frente com números medidos, achando que
tinha coberto.

No dia seguinte a pergunta do conselho foi *"e broadcast/re-engajamento?"*. A medição em produção
respondeu numa coluna: `last_reengage_sent_at = 2026-06-12`. **A pessoa já tinha recebido**, meses
antes e em silêncio, um texto escrito para outro público.

**Por que a lista dos leitores não bastou:** filtrar leitor conserta **relatório**; filtrar emissor
conserta **o que a pessoa recebe no celular**. O segundo é o que o usuário final percebe.

**Como aplicar:** ao introduzir a marca, varra DUAS listas antes de fechar —
1. quem **LÊ** a entidade (métrica, resumo, board, export);
2. quem **ENVIA** para ela (cron de reengajamento, broadcast, lembrete, alerta, convite, recuperação
   de carrinho) — e para cada um pergunte *"o texto é escrito para quem?"*.

E **meça no banco se já aconteceu** (`last_*_sent_at`, contadores de envio) em vez de raciocinar se
é possível. A resposta veio de uma coluna, não de uma dedução.

⚠️ Corolário que quase virou o defeito seguinte: **calar sem devolver é trocar de defeito.** Silenciar
um automatismo numa entidade e excluí-la dos coletores que a reativariam a deixa muda para sempre. O
retorno entra no mesmo commit — e, se for silencioso, ele **não pode herdar o gate de horário
comercial** dos coletores que mandam texto (senão o silêncio dura a noite inteira).

Visto em: tiatendo, 2026-07-28 (`0.254.0`/`0.255.0`).
