## Alvo de mutação que sobrevive DUAS vezes pode não ser teste fraco — pode ser código MORTO {#mutacao-sobrevivente-pode-acusar-codigo-morto}

`tags: mutacao, alvo sobrevivente, guarda redundante, codigo morto, guarda mascarada, hash randomizado, PYTHONHASHSEED, teste em subprocesso, R23`

**Sintoma:** um alvo de mutação apaga o que parece uma guarda de verdade, a suíte fica **verde**, e
o reflexo é escrever um teste novo para "cobrir a decisão". O teste novo é escrito, e o alvo
**sobrevive de novo**.

**Causa raiz — na segunda sobrevivência, pare de escrever teste e vá medir a alcançabilidade.** No
caso real (tiatendo, N33, 2026-08-22) a "guarda" era um piso repetido dentro de um bloco:

```python
if perto:                                  # <- guarda de fora
    ...
    if any(len(t) >= 3 and ... for t in sobrando):   # <- o "piso" mutado
```

`perto` só é não-vazio quando **algum** item cobre um token de ≥3 caracteres com letra; esse token,
por ser coberto, está necessariamente em `sobrando`. **A condição interna nunca podia ser falsa.**
Não havia teste capaz de matá-la porque não havia comportamento a observar: era código morto.

**Solução:** guarda redundante é **tesoura ou morta** — corte a linha, e reaponte o alvo para o
crivo **real** (o de fora, herdado). Mantenha um teste que asserta o **RESULTADO** (`"ml gelada"`
não repesca), nunca a linha: assim ele sobrevive a quem reorganizar os blocos, e continua matando o
alvo verdadeiro.

**O caso oposto, na mesma rodada — sobrevivente que É buraco real, e o instrumento estava errado:**
outro alvo trocava `zlib.crc32(texto)` por `hash(texto)` e sobrevivia. `hash()` de `str` em Python é
**randomizado por processo** (`PYTHONHASHSEED`), mas **estável dentro** dele — então nenhum teste
in-process consegue ver a diferença, por mais asserções que tenha. Só morre com um teste que roda o
mesmo caminho em **subprocessos** com sementes diferentes:

```python
for semente in ("0", "1", "12345"):
    r = subprocess.run([sys.executable, "-c", codigo], capture_output=True, text=True,
                       env={**os.environ, "PYTHONHASHSEED": semente})
    saidas.add(r.stdout.strip())
assert len(saidas) == 1
```

🔑 **A distinção entre os dois casos:** pergunte *"existe estado do mundo em que esta linha muda o
resultado?"*. **Não existe** → código morto, corte. **Existe mas o harness atual não o alcança**
(processo, relógio, locale, ordem) → o teste precisa de **outro instrumento**, não de outra
asserção.

**Bônus medido na mesma rodada:** ao editar o código, um terceiro alvo deixou de casar o texto
original e o script o marcou **PODRE** em vez de contar como morto — que é o comportamento correto,
e é o que separa `6/6 mortos` real de falso verde. Ver
[#alvo-de-mutacao-pode-nascer-podre].

**Ref:** tiatendo, N33, 2026-08-22. Commit `9048175`. Irmãos:
[#alvo-de-mutacao-pode-nascer-podre], [#mutacao-so-mata-o-que-o-call-site-observa],
[#guarda-redundante-tesoura-ou-morta]. R23.
