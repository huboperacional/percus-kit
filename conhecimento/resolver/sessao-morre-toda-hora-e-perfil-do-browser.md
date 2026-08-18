## Sessão que "morre toda hora" pode ser troca de perfil do browser, não bug de auth {#sessao-morre-toda-hora-e-perfil-do-browser}

`tags: sessao, localStorage, perfil do browser, chrome, OTP diario, refresh token, familia nunca rotacionada, falso bug de auth, origin`

**Classe de sintoma:** usuário relata que precisa relogar constantemente (OTP diário, sessão que não
persiste), enquanto o código de refresh está correto e o servidor mostra a sessão viva.

**A armadilha:** `localStorage` é por **origin E por perfil do browser**. Quem alterna entre perfis
do Chrome — comum em quem opera vários clientes — tem uma sessão viva num perfil e nenhuma no outro.
Do lado do servidor isso aparece como "família criada e nunca rotacionada", indistinguível de bug de
refresh. Duas equipes podem investigar código por semanas em cima de um número que não é de código.

**Como medir, sem depender do relato do usuário** (Windows/Chromium):
1. Mapear perfil → conta: `<User Data>/Local State`, campo `profile.info_cache`, que traz `name` e
   `user_name` (e-mail) de cada pasta `Profile N`.
2. Procurar a chave no disco: o `localStorage` fica em `<Profile N>/Local Storage/leveldb/*.{log,ldb}`.
   O registro tem o formato `_<origin>\x00\x01<nome-da-chave>` — regex sobre os bytes acha o par
   origin→chave sem abrir o browser.
3. Distinguir **sessão viva** de **resíduo**: se a chave aparece nos bytes mas o par
   `_origin\x00\x01chave` não é legível, são registros já compactados — ou seja, houve sessão ali e
   ela foi apagada. Presença de bytes não é presença de sessão.

**Ordem de eliminação que funcionou:** (a) configuração "limpar dados ao sair" (`Preferences`,
`profile.default_content_setting_values.cookies == 4`); (b) janela anônima — não persiste por
desenho, então **pergunte**, não deduza; (c) só então o código.

**Erro que cometi e custou uma rodada:** afirmei "não há sessão em perfil nenhum" com um scan que só
procurava a chave nos arquivos onde já tinha achado o origin. Um segundo scan, mais amplo, achou a
sessão viva noutro perfil. **Um scan que não encontra não prova ausência — prova que o scan não olhou
lá.** Antes de concluir "não existe", teste o scan contra um caso que você SABE que existe.

**Ref:** Micro Investors, 2026-08-17. Investigação que consumiu duas equipes desde julho fechou em
uma varredura de disco: o perfil do operador (`trafego@`) não tinha sessão; a viva estava em outro
perfil, de outra conta Google. Relacionado: `metrica-de-audience-mistura-clientes` (mesma família —
o número agregado escondia a heterogeneidade da população medida).
