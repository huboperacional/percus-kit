## Premissa de plano também é medição {#premissa-de-plano-tambem-e-medicao}

tags: plano, spec, conselho, verificacao, r2

**Sintoma.** Uma task do plano existe para preencher uma lacuna ("hoje o código não faz X", "hoje
não existe Y"). Você começa a executar, abre o arquivo citado — e X **já existe**. A task nunca
teve razão de ser.

**Caso que originou (Família Milionária, 2026-08-19).** O plano listava a lacuna *"assistente sem
nome nem persona"*, citando `app/modules/ai/service.py:293`. A **linha 292**, imediatamente acima,
era `"Você é a *Mia*, assistente financeira..."`, com bloco de personalidade completo em seguida. E
o nome não era rascunho: `CONTACT_DISPLAY_NAME = "Mia - Família Milionária"` é o que o bot **manda o
usuário salvar na agenda**; a landing usava em 4 sítios, o FAQ em 5, o editor de fluxo em 1.

**Por que passou.** A premissa atravessou spec, **pre-mortem de conselho de 3 membros** e uma sessão
inteira de execução sem ninguém abrir o arquivo. A citação vinha com `arquivo:linha` — e citação com
número de linha *parece* medição. O erro foi de **uma linha**.

**O custo que quase teve.** O agente levou a premissa ao operador como pergunta ("qual o nome da
assistente?"). O operador escolheu um nome novo sobre a informação falsa. A decisão real não era
batizar: era **renomear marca publicada**, incluindo o nome já salvo na agenda dos usuários — que o
produto não alcança. Só apareceu porque o agente foi medir antes de escrever o código.

**Procedimento.** Antes de executar uma task cuja justificativa é uma AUSÊNCIA:

1. Abra a referência citada e leia **o bloco**, não a linha. Off-by-one em citação é comum e
   invisível.
2. Faça um grep pelo conceito no repositório inteiro, não só no arquivo citado — o caso acima
   apareceria por `rg -n '\bMia\b'` em 1 segundo.
3. Se a task tem alcance externo (marca, contrato, dado que o usuário já guardou), medir vira
   **pré-requisito de perguntar ao operador**, não de codar: uma pergunta feita sobre premissa
   falsa contamina a resposta dele.

**Sinal de alerta específico.** Desconfie de lacuna redigida como *"o prompt diz só X"* / *"a única
coisa que existe é X"*. "Só" e "única" são quantificadores, e quantificador é afirmação medível que
raramente foi medida.

Ver também: [trava-vermelha-no-dia-1](trava-vermelha-no-dia-1.md) · [trava-por-substring-aceita-mencao](trava-por-substring-aceita-mencao.md)
