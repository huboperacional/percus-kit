## Defeito que o serviço remoto ACEITA é latente, não risco {#defeito-latente-aceito}

`tags: defeito latente, dado malformado, httpx, ReadTimeout, str(exc) vazio, mensagem de erro vazia, espaço em identificador, normalizar na porta, string vazia vs None, medir antes de classificar`

**Sintoma:** você acha um dado malformado em produção (um id com espaço, um corpo de erro vazio) e
classifica como risco. Ninguém nunca reportou nada.

**Causa:** o serviço remoto tolera. **Não há incidente, não há alerta, e ninguém investiga um envio
que funciona** — o defeito espera o dia em que outra ponta compara por igualdade.

**O que fazer:** **meça antes de classificar.** Dois casos medidos no mesmo dia:

- `fetch_error:` gravando corpo vazio — **8 de 8 registros em 30 dias**, porque as exceções de rede
  do `httpx` (`ReadTimeout`, `ConnectTimeout`, `ConnectError`, `RemoteProtocolError`) são levantadas
  **sem argumento** e `str(exc)` é `""`. Grave sempre o **tipo** da exceção, mesmo quando há
  mensagem: corpo vazio não é só inútil, é **ambíguo** (não se distingue de "o servidor respondeu
  vazio").
- `meta_pixel_id` com espaço à esquerda — **o Meta aceitou**, 7 de 7 eventos recebidos. Latente, não
  quebrado. Normalize **na porta** (o dado sujo não chega a existir) e faça `"   "` virar `None`,
  nunca `""`: vazio numa coluna que o dispatch lê significa "configurado com nada" e monta URL sem
  id; `None` significa "não configurado", que é o que tela e monitor sabem ler.

Relacionado: {#drop-table-rollback-pareado}.
