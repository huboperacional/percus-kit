## `<form action={serverAction}>` reseta os campos quando a ação retorna — inclusive retornando erro {#form-action-do-react-reseta-os-campos-no-erro}

`tags: react 19, next.js, server action, useActionState, formulario, reset, campo controlado, select, datalist, checkout, caminho do erro`

**Sintoma:** o formulário valida no servidor, devolve `{ ok: false, erro: '...' }`, a mensagem aparece na tela — **e todos os outros campos estão vazios**. O usuário errou um dígito num campo e perdeu os outros onze. Nenhum erro no console, nenhum aviso de build.

**Causa raiz:** o React reseta o formulário depois que uma ação passada em `<form action={...}>` termina. Ele não distingue sucesso de erro — a ação **retornou**, então o formulário volta ao estado inicial. Com campos não controlados (`defaultValue` ou nada), o valor digitado some.

Isso só aparece testando o **caminho do erro**. Quem testa o caminho feliz vê a ação redirecionar e nunca encontra o problema.

🔑 **Campo controlado resolve para input de texto — e não resolve para `<select>`.** Medido em 2026-08-20: com todos os campos em estado do React, `nome`, `email`, `telefone`, `cep` e `logradouro` sobreviveram ao erro, e o `<select>` de UF voltou vazio.

A razão é que o React reescreve o DOM de um input controlado no render seguinte, mas num `<select>` cujo valor virtual **não mudou** ele não toca no DOM — e o DOM foi zerado pelo reset. O estado está correto; a tela é que não.

**Solução:**

1. Todos os campos controlados, com estado num objeto só:
   ```tsx
   const [d, setD] = useState<Dados>(VAZIO)
   <input value={d.nome} onChange={(e) => setD((x) => ({ ...x, nome: e.target.value }))} />
   ```
2. Para o que seria `<select>`, use **input com `datalist`**:
   ```tsx
   <input list="ufs" value={d.uf} onChange={...} maxLength={2} />
   <datalist id="ufs">{UFS.map((u) => <option key={u} value={u} />)}</datalist>
   ```
   É input de texto, então o React o restaura. E dá o mesmo autocompletar.
3. O `<datalist>` fica **uma vez** no formulário, não dentro do componente de campo reaproveitado — dois elementos com o mesmo `id` é HTML inválido, e o `list` de um dos inputs aponta para o lugar errado.

❌ **Não tente consertar com `key` no `<select>`.** Parece a saída óbvia — mudar a `key` a cada envio remonta o elemento com o valor certo. Não funciona: o remonte acontece **antes** do reset do formulário, e o reset apaga de novo. Foi testado em produção e falhou.

⚠️ **O teste que encontra isso é submeter com um campo inválido, não com todos válidos.** Vale como hábito: em formulário de mais de três campos, o primeiro teste é o do erro.
