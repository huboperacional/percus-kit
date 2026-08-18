## Mock de função de BANCO no arquivo de mocks de REDE → erro que não fala do seu problema {#mock-de-banco-em-arquivo-de-rede}

`tags: pytest, fixture, mock, outbound, FOREIGN KEY constraint failed, sqlite, uuid fake, harness de teste, erro enganoso`

**Origem:** Família Milionária, 2026-07-29 — mordeu 7 arquivos de teste antes de alguém arrumar a causa.

`tests/harness/outboundPatches.py` existe pra mockar o que sai pra **rede**. Alguém pôs ali
`catService.getOutrosId` — que é uma função de **banco** — devolvendo um UUID fixo
(`00000000-…-0001`) que não existe como linha. Resultado: todo teste que gravasse a entidade morria
com `FOREIGN KEY constraint failed`, um erro que **não menciona categoria nenhuma**.

Cada um dos 6 arquivos anteriores contornou localmente (re-mockando pro id real) em vez de remover o
mock. E um deles chegou a **abrir mão de uma asserção** por causa disso — a armadilha custou
cobertura, não só tempo.

- **A regra:** arquivo de mocks tem um escopo declarado. Função que não bate com o escopo não entra —
  e quando o contorno local aparece pela 2ª vez, o problema é a causa, não o contorno.
- **Sintoma-assinatura:** erro de integridade referencial que não cita a entidade que você está
  criando + vários arquivos de teste com o mesmo `monkeypatch` defensivo copiado.
