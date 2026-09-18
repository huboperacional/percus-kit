## Prova de teste precisa provar que o teste EXISTE e FOI COLETADO — ausência vira "vermelho" falso ou "verde" vazio {#prova-de-teste-precisa-provar-que-o-teste-existe-e-foi-coletado}

`tags: sabotagem, pytest, playwright, rc 4, rc 5, no tests found, testMatch, coleta, prova falsa, script, R23`

**Sintoma:** duas faces do mesmo erro, medidas em 18/09/2026 (Empresa Milionária, Tasks 14 e 20 da NFS-e):

1. **Vermelho falso.** Um script de sabotagem roda o teste-guarda e conclui "vermelho = pegou" por `returncode != 0`.
   Rodado antes de a guarda existir, o pytest devolve **rc 4** (nodeid não encontrado) — e o script reportaria prova.
   O Playwright faz o mesmo com `No tests found` (rc 1).
2. **Nunca coletado.** Um spec novo do Playwright chamado `formato-documento-pessoa.spec.ts` não casava o `testMatch`
   do config que roda a suíte (`(pj-|guarda-).*\.spec\.ts`). Não falharia: simplesmente não rodaria em lugar nenhum.

**Causa:** "o comando falhou" e "o teste afirmou e falhou" têm o mesmo `returncode`; "o teste passou" e "o teste não
existe para este config" têm o mesmo silêncio.

**Solução:**
- No script de sabotagem, trate como **AUSENTE, nunca como prova**: pytest rc 4 e 5, `no tests ran`, e no Playwright
  `No tests found` ou saída sem placar. Só conta vermelho com placar `N failed`.
- Filtro `-g` do Playwright sem âncora (o título inclui arquivo e describe) e só ASCII (acento pode chegar mutilado).
- Arquivo de teste novo: `playwright test --config=<o config> --list <arquivo>` (ou `pytest --collect-only`) ANTES de
  rodar, e confira a contagem listada.

**Verbetes relacionados:** `sabotagem-que-nao-aplica-reporta-verde.md`,
`parametrize-sobre-tabela-vazia-vira-skip-e-a-guarda-mora-na-tabela.md`.
