## Estreitar um `except` troca "engole demais" por "escapa o que importa" {#estreitar-except-troca-engolir-demais-por-escapar-o-que-importa}

`tags: python, except, exception, regressao, review, finding, ZoneInfo, OSError, tzdata, conserto que quebra, enumerar excecoes, scheduler, job`

**Sintoma:** um review acha um `except Exception` largo demais e pede para estreitar. Você
estreita, a suíte fica verde, o commit sai — e o processo passa a **morrer** numa entrada que
antes só gerava um `warning`. A regressão nasce do conserto, e o teste que a pegaria não existe
porque ninguém escreve teste para a exceção que não imaginou.

**Causa raiz:** estreitar exige saber **o conjunto real** do que o miolo levanta. Quase sempre a
lista sai da cabeça (*"isso aqui levanta `ValueError` e `TypeError`"*) em vez de sair da
biblioteca. E o conjunto real depende de coisas que não estão no código que você está olhando:
sistema de arquivos, encoding, versão do runtime.

**Caso medido:** validação de fuso horário num job.

```python
# antes (o finding: engole ate KeyboardInterrupt e mascara bug de programacao)
try:
    local = agoraUtc.astimezone(ZoneInfo(fuso))
except Exception:
    logger.warning("fuso_invalido"); return False

# depois do conserto -- e o OSError agora ESCAPA e derruba o tick
except (ZoneInfoNotFoundError, ValueError, TypeError):
```

`zoneinfo._common.load_tzdata` só captura `(ImportError, FileNotFoundError,
UnicodeEncodeError)` para converter em `ZoneInfoNotFoundError`. Um nome com caractere inválido
para o sistema de arquivos escapa como **`OSError` cru**. Conferido no venv do projeto:

```
>>> ZoneInfo("a?b")
OSError: [Errno 22] Invalid argument: '.../zoneinfo/a?b'
```

Um `fuso` desses vem do **banco**, não do código — uma linha com dado sujo derrubaria o job da
empresa inteira, e o comportamento correto (pular a empresa com um `warning`) estava lá antes do
conserto.

⚠️ **Para reproduzir, o venv importa** — e isso é parte da lição: o mesmo `ZoneInfo("a?b")` levanta
`ZoneInfoNotFoundError` (não `OSError`) num ambiente **sem o pacote `tzdata`**, porque aí o
`load_tzdata` nem chega ao sistema de arquivos. O `OSError` aparece justamente no ambiente que
**parece mais completo**. E a tupla capturada muda por versão: no Python 3.12 são três itens, no
3.14 já são quatro (`+ IsADirectoryError`). Ou seja, o conjunto que você está afirmando depende de
**runtime e de dependência instalada**, não só da biblioteca — mais uma razão para lê-lo em vez de
lembrá-lo.

**Solução:**

1. **Enumere lendo a fonte, não a memória.** Abra o `except` da própria biblioteca (`inspect
   .getsource`, ou o arquivo no venv) e veja o que ela converte e o que ela deixa passar. Foi só
   isso que revelou o `OSError` aqui.
2. **Exercite a fronteira, não o caminho feliz.** Um teste por *modo de falha* — nome inexistente,
   nome com caractere inválido, `None`, número — e cada um asserindo o comportamento **degradado**
   (`return False` + `warning`), não só "não explode".
3. **Prefira estreitar por CAMADA a estreitar por TIPO** quando o conjunto é aberto: capture largo
   no laço por item (para um item ruim não derrubar os outros) e deixe o `except` estreito só onde
   você controla o que é levantado.
4. Se mesmo assim for capturar largo, capture `Exception` e **re-levante o que não é seu**:
   `except Exception as e: if isinstance(e, (KeyboardInterrupt, SystemExit)): raise` — embora
   esses dois já não sejam `Exception`, o padrão vale para as classes do seu domínio.

**🔑 A regra que fica:** todo `except` estreitado é uma **afirmação sobre o que o miolo levanta**,
e afirmação se mede. Se você não abriu a biblioteca, você não estreitou — você chutou. E o chute
aqui não falha no teste: falha em produção, na linha suja que ninguém tinha.

**Ref:** 2026-09-10, Empresa Milionária — fatia 4 Task 12, `scheduler/link_do_dia.py`, commit
`fa03967`. O `OSError` foi devolvido ao `except` na **segunda rodada** do cross-Claude, que estava
revisando o conserto da primeira. Duas lições no mesmo lugar: a de cima, e que **re-revisar o
conserto é uma rodada separada** — o revisor que só vê o diff original não vê a regressão que o
diff de conserto introduziu.
