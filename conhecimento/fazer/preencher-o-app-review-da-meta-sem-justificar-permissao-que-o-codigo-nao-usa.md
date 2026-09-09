## Preencher o App Review da Meta sem justificar permissão que o código não usa {#preencher-o-app-review-da-meta-sem-justificar-permissao-que-o-codigo-nao-usa}

`tags: meta, app review, instagram, facebook, permissoes, oauth, submission, screencast, tratamento de dados, plataforma, reviewer account`

**Quando:** qualquer produto que integra login/permissões da Meta (Instagram Business Login,
Facebook Login) precisa passar pelo formulário de App Review antes de liberar pra usuários que não
são testers do app.

### 1. Confira as permissões pedidas contra o código ANTES de escrever justificativa

O formulário lista as permissões que **você mesmo** adicionou em algum momento — não é raro sobrar
uma que o código nunca usa (ex.: `instagram_business_content_publish` numa integração que só lê
comentário e manda DM, nunca publica conteúdo). Justificar uma permissão sem uso real é motivo
clássico de recusa.

```sh
grep -rn "instagram_business_\|<escopo>" app/ lib/ --include="*.ts" | grep -v node_modules
```

Se a permissão não aparece em lugar nenhum do código, **remova do envio antes de escrever qualquer
justificativa** — o botão de remover geralmente está na própria tela de permissões da submissão
("edite-o" / lixeira ao lado de cada uma), não em "Casos de uso" (que é onde a Meta manda você ir
pra remover **do app**, não só desta submissão — path diferente, efeito mais amplo do que você quer).

⚠️ **A permissão base não sai.** `instagram_business_basic` costuma ser dependência obrigatória das
outras (`manage_messages`, `manage_comments` etc. dizem explicitamente "seu envio deve incluir
`instagram_business_basic`") — a Meta força ela a ficar mesmo que você tente remover.

### 2. "Uso permitido" tem um padrão fixo por permissão: descrição + screencast + conformidade

Cada permissão abre um modal com 3-4 blocos, sempre nesta ordem:
1. Caixa de texto: descrição de como o app usa a permissão — funciona bem ancorada em código real
   (arquivo:linha exatos), não em prosa genérica.
2. Upload de **screencast** — é vídeo, não print. A Meta é explícita: "Carregue uma gravação de
   tela". Um print estático não substitui isso; não anexe um fingindo que é.
3. (Só em algumas permissões) "Verifique se você fez as ligações de teste de API exigidas" — se
   você já rodou chamadas reais contra a permissão em ambiente de teste, isso aparece **já marcado
   como "Concluída"** (bolinha verde), sem ação sua.
4. Checkbox de conformidade de uso.

Salvando o modal (mesmo sem o vídeo), os itens preenchidos ficam com ✓ verde e o item do vídeo fica
cinza pendente — dá pra ver exatamente o que falta, por permissão, sem adivinhar.

**Uma permissão pode ter uma pergunta a mais** ("Responda a perguntas personalizadas para
desenvolvedores/fornecedor de tecnologia") que aparece como bullet separado na lista de fora, mas
**não é um formulário à parte** — é satisfeita pelo mesmo modal de descrição, via um bloco
"Instructions for Developers" com requisitos específicos de screencast e do que incluir na
descrição (ex.: link do post de teste, credencial da conta de revisor). Confirmado salvando: o
bullet vira ✓ verde junto com os outros, sem nunca abrir formulário separado.

### 3. Nunca escreva `[PENDENTE: ...]` dentro de um campo que vai pra Meta

Um placeholder-lembrete (tipo "falta a credencial da conta de revisor") é útil **para você**, nunca
para o texto que a Meta vai ler. Se falta um dado real (credencial, link de post), ou você deixa o
campo vazio e volta depois, ou usa outro mecanismo (arquivo de rascunho à parte, comentário de
código) — nunca embuta a nota dentro do texto que seria colado no formulário. Confundir rascunho com
texto final é o erro mais fácil de cometer numa sessão longa de preenchimento.

### 4. "Tratamento de dados" é atestação jurídica, não descrição técnica

Ao contrário de "Uso permitido" (você pode responder sozinho, ancorado em código), esta aba pergunta
fatos de negócio que só o operador sabe: nome da entidade responsável (CPF/CNPJ), país, histórico de
pedido de autoridade pública, processos formais aplicados. **Não deduza nem suponha** — pare e
pergunte. A única pergunta que dá pra responder com evidência de código é "você tem operador de
dados/provedor de serviço com acesso aos Dados da Plataforma?" — se o produto manda dado recebido da
Meta (username, texto de comentário, id) pra uma API de terceiro (Anthropic, OpenAI, um CRM), a
resposta é Sim, mesmo que a feature esteja atrás de uma flag desligada — a pergunta é sobre
capacidade do código, não sobre tráfego real hoje.

Ao adicionar um operador de dados no formulário: a lista de categoria/país é um combobox **que
reabre a cada clique fora de uma opção** — clicar duas vezes seguidas na MESMA lista (achando que a
segunda vai na próxima pergunta) marca uma segunda opção errada por engano. Feche a lista clicando
num elemento de texto neutro do modal antes de abrir a próxima, não em qualquer ponto da tela.

### 5. "Instruções para o analista" pode ficar bloqueada por um pré-requisito de fora das 5 abas

Antes de liberar essa aba, a Meta exige pelo menos uma **Plataforma** declarada em
Configurações do app → Básico → Adicionar plataforma (Site/iOS/Android/...). Sem isso, a aba mostra
só um aviso e um botão "Acessar configurações" — não é bug, é sequência do formulário. Pra um app
puramente web, "Site" com a URL de produção resolve.

Dentro dela, o campo "O Login do Facebook está integrado a esta plataforma?" pergunta sobre
**Facebook Login como produto** (o antigo login social genérico, com `email`/`user_gender` etc.) —
uma integração via Instagram Business Login (OAuth específico pra conectar conta profissional, não
pra autenticar o usuário do seu app) responde **Não** aqui, mesmo usando infraestrutura OAuth da
Meta por baixo.

### 6. O bloqueio real costuma ser a credencial de revisor, não o formulário

Se o produto não tem senha (login por OTP/magic link), o formulário vai pedir repetidamente
"credenciais de teste para o revisor acessar o app" — em pelo menos dois lugares (instruções de
acesso da permissão, e de novo em "Instruções para o analista"). Sem uma conta que aceite login
**sempre**, sem depender de entrega real de código, nenhum desses campos fecha de verdade. Resolver
isso geralmente precisa de mudança no serviço de autenticação (se for compartilhado entre produtos,
trate como mudança arquitetural — desenho antes de código).

**Ref:** LiliFlow, sessão de preenchimento em 2026-09-08.
Relacionado: `docs/superpowers/specs/2026-09-08-liliflow-meta-reviewer-fixed-code-design.md` (não é
canon cross-projeto, é spec local do produto — cite se for reaproveitar o desenho de credencial fixa
escopada por audience noutro produto).
