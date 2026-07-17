# Guia fácil: como baixar dados de sequenciamento e obter os arquivos FASTQ

Um guia sem jargão para quem nunca trabalhou com bioinformática.
Ao final há uma **legenda** explicando cada palavra técnica (marcadas com ⭐).

> Referência rápida de comandos e opções: [README](../README.md).

---

## Antes de tudo: qual é a ideia?

Quando um laboratório no mundo faz o ⭐**sequenciamento** de um organismo (um vírus, uma bactéria, um animal), ele costuma **depositar esses dados em bibliotecas públicas na internet**, para que qualquer pesquisador possa usá-los.

Pense nessas bibliotecas como um **acervo digital gigante**:

- Cada conjunto de dados tem um **código de catálogo** (o ⭐**accession**), como o ISBN de um livro.
- O "livro" em si é um arquivo chamado ⭐**FASTQ**: um texto enorme com as "letras" do material genético (A, T, C, G).

O que fazemos aqui é o equivalente a **ir até a biblioteca, pegar o livro certo pelo código e trazer uma cópia para o seu computador** — conferindo que nenhuma "página" veio faltando.

O script `fetch_fastq.sh` automatiza esse trabalho todo.

---

## O que você precisa ter antes de começar

Alguns "programas ajudantes" precisam estar instalados no computador. É como precisar de um leitor de PDF antes de abrir um PDF. A forma mais simples de instalar tudo de uma vez é com um gerenciador chamado ⭐**conda**:

```bash
conda env create -f environment.yml
conda activate fastq-fetch
```

> Se você for usar só a rota mais simples (a "ENA", explicada adiante), a maioria dos computadores já vem com o necessário (`curl`, `md5sum`, `awk`). O comando acima cobre as duas rotas.

> 🪟 **Está no Windows?** Esse comando **não vai funcionar** — os programas de bioinformática não têm versão Windows. Siga o [guia específico de Windows](guia_windows.md) antes de continuar.

---

## As duas "rotas" (caminhos) para baixar

Os mesmos dados costumam existir em **dois acervos diferentes**. O script deixa você escolher qual usar:

| Rota | Nome | Quando usar | Analogia |
|------|------|-------------|----------|
| **ENA** | biblioteca europeia | **Padrão. Comece por ela.** É mais rápida porque o arquivo já vem pronto. | Pegar o livro já impresso na prateleira |
| **SRA** | biblioteca americana (NCBI) | Quando o dado só existe lá, ou a ENA não tem. | Pegar o manuscrito e imprimir você mesmo |

Não precisa decorar: por padrão o script usa a **ENA**. Se ela não tiver o arquivo, ele te avisa para trocar — aí é só repetir o comando acrescentando `-s sra`.

---

## Passo a passo para usar

### Passo 1 — Dar permissão para o script rodar

Só na primeira vez. É como "destravar" o arquivo:

```bash
chmod +x fetch_fastq.sh
```

### Passo 2 — Descobrir qual é o seu código (accession)

Você precisa saber **o que** quer baixar. Existem tipos de código:

- Começa com **SRR**, **ERR** ou **DRR** → é um ⭐**run** (uma amostra individual). **É o que vira FASTQ.**
- Começa com **PRJNA**, **PRJEB** ou **SRP** → é um ⭐**projeto inteiro** (várias amostras de uma vez).

Você encontra esses códigos no artigo científico ou no site da biblioteca.

### Passo 3 — Rodar o comando

Escolha o caso que combina com você:

**a) Baixar UMA amostra:**
```bash
./fetch_fastq.sh -a SRR1234567
```
Leitura: *"baixe a amostra (`-a`) de código SRR1234567"*.

**b) Baixar VÁRIAS amostras de uma lista:**

Primeiro crie um arquivo de texto com um código por linha (veja o modelo em `examples/accessions.txt`). Depois:
```bash
./fetch_fastq.sh -i examples/accessions.txt -o ./meus_dados -t 8
```
Leitura: *"use a lista (`-i`) do arquivo, salve na pasta `meus_dados` (`-o`) e use 8 ⭐threads (`-t`) para ir mais rápido"*.

**c) Baixar um PROJETO inteiro:**
```bash
./fetch_fastq.sh -p PRJNA123456 -o ./meus_dados
```
Leitura: *"pegue o projeto (`-p`) inteiro e descubra sozinho todas as amostras dele"*.

### Passo 4 — Aguardar e conferir

O script vai mostrando na tela o que está fazendo. Ao terminar, na sua pasta de saída você encontra:

- Os arquivos **`.fastq.gz`** → seus dados (o `.gz` significa que estão ⭐compactados, para ocupar menos espaço).
- Um arquivo **`.log`** → o "diário de bordo": tudo que aconteceu, com data e hora. Útil se algo der errado.
- Um arquivo **`samplesheet.csv`** → uma **tabela-resumo** listando cada amostra e seus arquivos. Serve de "ficha de entrada" para os programas de análise seguintes.

---

## O que o script faz por baixo dos panos (sem susto)

Você não precisa entender isto para usar — mas ajuda a confiar no processo. Em ordem:

1. **Confere se os ajudantes estão instalados.** Se faltar algum, ele avisa e para, em vez de falhar no meio.
2. **Descobre a lista de amostras.** Se você deu um projeto inteiro, ele lista sozinho todas as amostras.
3. **Baixa cada arquivo.**
4. **Confere a integridade (o passo mais importante).** Cada arquivo vem com uma "impressão digital" chamada ⭐**MD5**. O script recalcula essa impressão do arquivo baixado e compara com a original. Se baterem, o arquivo veio inteiro; se não, ele descarta e tenta de novo. É a garantia de que **nenhum dado veio corrompido**.
5. **Organiza e compacta** os arquivos e gera a tabela-resumo.

Se a internet cair no meio, é só rodar de novo: ele **continua de onde parou**, sem baixar tudo outra vez.

---

## Como saber se deu certo?

O script termina com um resumo do tipo `Succeeded: 3/3`. Além disso, ele devolve um **código de saída**:

| Código | Significado |
|--------|-------------|
| `0` | Tudo certo. |
| `1` | Erro de uso (comando errado) ou falta de programa instalado. |
| `2` | Alguma amostra falhou no download ou na conferência do MD5. |

Se aparecer código `2`, o script lista quais amostras falharam — normalmente é só tentar a outra rota com `-s sra`.

---

## Legenda (glossário dos termos ⭐)

**Sequenciamento** — Processo de "ler" o material genético (DNA ou RNA) de um organismo e transformá-lo em texto: uma longa sequência de letras (A, T, C, G).

**FASTQ** — O formato de arquivo que guarda esse texto genético lido pela máquina. Além das letras, guarda também um "nível de confiança" de cada letra. É o produto final que queremos.

**Accession** — O código único de catálogo de um dado na biblioteca pública, como o ISBN de um livro. Ex.: `SRR1234567`.

**Run** — Uma "corrida" de sequenciamento: os dados de **uma amostra individual**. É o nível que efetivamente vira um arquivo FASTQ. Códigos: SRR, ERR, DRR.

**Projeto / BioProject** — Um guarda-chuva que agrupa **várias amostras** de um mesmo estudo. Códigos: PRJNA, PRJEB, SRP.

**ENA e SRA** — As duas grandes bibliotecas públicas de sequenciamento. ENA é europeia (arquivo já pronto, mais rápido); SRA é americana (NCBI). Costumam ter os mesmos dados.

**conda** — Um "instalador organizado" de programas científicos. Resolve para você tudo que um programa precisa para funcionar.

**Thread** — Um "trabalhador" do processador. Usar mais threads (`-t 8` = 8 trabalhadores) faz o computador dividir a tarefa e terminar mais rápido — desde que sua máquina tenha essa capacidade.

**MD5 (checksum)** — Uma "impressão digital" numérica do arquivo. Serve para conferir se o arquivo baixado é idêntico ao original, sem faltar nem corromper nada.

**Compactado (.gz)** — Arquivo "espremido" para ocupar menos espaço e baixar mais rápido, como um .zip. Os programas de análise leem o `.gz` direto, sem precisar descompactar.

**Log** — O "diário de bordo" do script: um arquivo de texto com o registro de tudo que ele fez, com data e hora. É onde você olha se algo não sair como esperado.

**Samplesheet** — Uma tabela (arquivo .csv, que abre no Excel) resumindo quais arquivos foram baixados para cada amostra. Serve de entrada organizada para as próximas etapas de análise.

---

## Resumo em uma frase

> Você informa um código, o script vai até a biblioteca pública, traz uma cópia conferida dos dados genéticos e ainda deixa tudo organizado para a próxima etapa.
