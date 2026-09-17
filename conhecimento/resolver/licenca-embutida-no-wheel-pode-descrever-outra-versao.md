## Licença embutida no wheel pode descrever outra versão da biblioteca nativa que ele carrega {#licenca-embutida-no-wheel-pode-descrever-outra-versao}

`tags: licenca, wheel, LICENSES_bundled, biblioteca nativa, versao, pi-heif, libheif, ldd, not found, auditoria, SBOM, R18, R23`

**Sintoma:** a auditoria de licença lê o `LICENSES_bundled.txt` do wheel, anota a versão da biblioteca nativa que ele cita
e dá o assunto por conferido. A versão citada não é a que roda.

**Caso concreto, medido em 16/09/2026 (Empresa Milionária, janela R20 M18, imagem Linux da API):** `pi_heif` 1.4.0
(wheel `manylinux_2_28_x86_64`). `pi_heif.libheif_version()` responde **1.23.0**, e o `.so` embutido se chama
`libheif-*.so.1.23.0`; o `LICENSES_bundled.txt` do MESMO wheel aponta `COPYING` e código-fonte da **v1.18.1**. A licença
não mudou entre as duas (LGPLv3 nas tags 1.0.0, 1.18.1 e 1.23.0, conferido antes na spec), mas o arquivo de licença do
wheel não descreve o binário que ele traz.

**Como conferir:** a versão vem do binário em execução (`libheif_version()` ou o nome/`SONAME` do `.so`), nunca do texto de
licença; confira a licença **na tag daquela versão**. Registre a divergência na evidência mesmo quando a licença é a mesma.

**Armadilha vizinha, mesma medição:** `ldd` rodado direto no `.so` embutido (`pi_heif.libs/libheif-*.so`) mostra a irmã
`libde265-*.so => not found`, e o `import pi_heif` funciona na mesma imagem — o carregamento pelo módulo resolve a irmã. `not
found` no `ldd` isolado de wheel `manylinux` não prova biblioteca ausente; prove pelo import (e, quando possível, decodificando
um arquivo real).
