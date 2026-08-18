## QR code de pareamento "não linka" → suspeite do SEU refresh antes de culpar o provedor {#qr-pareamento-expira}

`tags: qr code, whatsapp, pareamento, linkar dispositivo, nao consigo conectar, qr_duration, codigo expirado, gowa, whatsmeow, baileys, handshake ausente, loop de refresh, aba abandonada, host compartilhado, log flood, polling, visibilitychange, template literal, script inline sem teste`

**Sintoma:** usuário escaneia o QR e o celular diz "não é possível conectar novos dispositivos agora"; nos logs do servidor de WhatsApp **não aparece handshake nenhum**. A ausência de handshake parece provar que a recusa é do provedor — e foi o que nos fez perseguir "conta Business", "bug do iOS" e "versão do servidor" por semanas.

**Causa-raiz real:** o QR expira rápido (GOWA: `qr_duration: 30s`) e só é reemitido na próxima chamada de login. Se a UI busca o código **uma vez** e congela a imagem, quem demora mais que a janela escaneia um código morto — e o WhatsApp recusa isso **do lado dele**, antes de tocar o seu servidor. Daí o log limpo.

**Solução:**
1. **Teste decisivo e barato:** parear direto pela UI nativa do provedor (que auto-renova o QR). Funcionou lá e não no seu painel ⇒ o culpado é seu, não do provedor. Isso encerra a discussão em 2 minutos.
2. Renove o QR antes de expirar (`qr_duration - 5s`), mas **com teto** (ex.: 5 tentativas ≈ 2min) e um botão "gerar novo". Loop sem teto inunda host compartilhado — se o host é de outro time, isso vira incidente **deles** (nos cegou durante a investigação de uma queda real).
3. ⚠️ **Não use o status da conexão como sinal de "pareando".** O provedor reporta `is_logged_in:false` para device não pareado, o que normaliza para `disconnected` — que também é o estado ocioso. Parar o loop nesse status mata o refresh ~200ms depois do clique (loop roda **zero** vezes); e quando o poll de status falha, a linha fica `connecting` e o loop roda **para sempre**. Os dois sintomas, opostos, têm a mesma raiz. Use um **orçamento de tentativas explícito**, não o status.
4. **Trave também no servidor** (429 por instância). É o único mecanismo que alcança **abas já abertas** rodando o JS antigo — um fix só no cliente não chega nelas. Bônus: clientes antigos costumam parar o loop em qualquer resposta não-OK, e se o refresh automático deles é silencioso, o 429 os aposenta sem erro visível.
5. Não renderize QR persistido em banco numa recarga de página: sem timestamp, ele está sempre vencido.

**Armadilha de processo:** JS de painel dentro de template literal não é lido pelo `tsc` **nem por teste nenhum** — foi assim que o bug subiu com "build verde". Extraia a lógica de decisão para um módulo compilado **pelo mesmo source** que a página e pelo spec, e teste "parar" e "exibir" como complementos exatos (property test) — eles divergiram e um status exibia QR enquanto cancelava o próprio refresh.

**Ref:** GHL-GOWA-WhatsApp, 2026-07-16/19. Cliente pagante 3 dias sem conseguir parear. Commits `3b55593`, `4ddd027`. Memória: `gowa-linking-blocked-whatsapp-side`.
