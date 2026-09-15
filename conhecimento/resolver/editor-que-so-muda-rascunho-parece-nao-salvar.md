## "Não está salvando" num editor que funciona: a mudança só vai ao rascunho e quem grava é um botão longe da vista {#editor-que-so-muda-rascunho-parece-nao-salvar}

`tags: nao salva, autosave, rascunho, botao salvar, audit_log, override, nomenclatura, ux, falso bug, dado nunca chegou`

**Sintoma:** o operador adiciona uma tag num card, ela aparece na tela, e ele diz que "não está salvando". Os
testes do componente e da rota passam; o PUT funciona quando chamado.

**Causa (medida, Paid Media Automation, 15/09/2026):** adicionar só mudava o estado local (`draft`); gravar
dependia de um botão "Salvar override" no FIM da página, sem nenhum sinal de alteração pendente. O último
salvamento do cliente no `audit_log` era de 18 dias antes — nada do que ele adicionou chegou ao servidor.

**Como provar antes de mexer:** procure a trilha de escrita no banco (auditoria, `updated_at`) no período em
que o operador diz ter editado. Sem linha = o dado nunca saiu do navegador; o bug é de fluxo, não de
persistência.

**O que fazer:** salvar a cada mudança com status explícito ("Salvando… / Salvo às HH:MM / Não salvou —
tentar de novo"). Ao implementar, espere 4 corridas que o review cruzado encontrou uma a uma:
1. PUT em voo que termina depois de o usuário trocar de modo (ex.: "herdar padrão") reescreve o estado;
2. troca de cliente com PUT pendente sobrescreve o estado do cliente novo;
3. zerar a fila DEPOIS do `await` apaga a edição feita durante o PUT (e a tela diz "Salvo");
4. dois PUTs em voo chegam fora de ordem no servidor e gravam a versão velha — serialize (um PUT por vez,
   sempre o mais novo), não aborte.

**Armadilha vizinha:** se a mesma tela recebe dado por outro caminho (ex.: aprovação de fila gravando no
padrão da "casa" para um cliente com override), isso também parece "não salvou" — confira os dois caminhos.
