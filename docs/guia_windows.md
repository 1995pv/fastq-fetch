# Guia Windows: rodando o pipeline do zero

Este guia é para quem está no **Windows** e nunca usou terminal. Ele existe porque quase toda documentação de bioinformática assume que você está no Linux — e não avisa onde isso te quebra.

> Guia conceitual (o que é FASTQ, accession, MD5): [`guia_pt.md`](guia_pt.md).

---

## A verdade que ninguém te conta primeiro

**Ferramentas de bioinformática não rodam no Windows.** Não é limitação do script — é da área inteira. O SRA Toolkit, o FastQC e praticamente todo o bioconda são compilados só para Linux e Mac.

Então `conda env create -f environment.yml` **vai falhar** se você rodar no PowerShell do Windows. Não é erro seu.

Você tem duas saídas:

| | Rota A — Git Bash | Rota B — WSL |
|---|---|---|
| **O que instala** | só o Git for Windows | um Ubuntu dentro do Windows |
| **Rotas de download** | só ENA | ENA **e** SRA |
| **Usa conda?** | não precisa | **sim — é aqui** |
| **Serve para o resto?** | não | sim (FastQC, MultiQC, tudo) |
| **Esforço** | 5 minutos | 30 minutos |

**Recomendação honesta:** se você só quer baixar uns FASTQ hoje, Rota A. Se você quer trabalhar com bioinformática, faça a Rota B agora. Você vai precisar dela de qualquer forma, e adiar só empurra a dor para frente.

---

## Rota A — Git Bash (rápida, só ENA)

O Git for Windows instala junto um terminal Linux-like chamado **Git Bash**. Ele já traz `curl`, `md5sum` e `awk` — as três únicas coisas que a rota ENA precisa.

**1.** Instale o Git for Windows, se ainda não tiver: [git-scm.com/download/win](https://git-scm.com/download/win)

**2.** Abra a pasta do projeto no Explorer → clique com o botão direito num espaço vazio → **Git Bash Here**.

> No VS Code: clique na setinha `∨` ao lado do `+` no terminal → escolha **Git Bash**. O PowerShell **não** roda este script.

**3.** Rode:

```bash
bash fetch_fastq.sh -a SRR15829425 -o ./dados
```

Pronto. Se pedir a rota SRA (`-s sra`), aí não tem jeito: precisa da Rota B.

---

## Rota B — WSL (completa)

WSL = Windows Subsystem for Linux. É um Ubuntu de verdade rodando dentro do seu Windows, sem máquina virtual e sem formatar nada. É assim que a maioria dos bioinformatas que usam Windows trabalha.

### B1. Instalar o WSL

Abra o **PowerShell como administrador** (tecla Windows → digite `powershell` → botão direito → *Executar como administrador*) e rode:

```powershell
wsl --install
```

Reinicie o computador. Ao voltar, abre sozinho uma janela preta pedindo para criar **usuário e senha do Linux**.

> ⚠️ Ao digitar a senha do Linux, **nada aparece na tela**. Nem asteriscos. É normal — o mesmo comportamento do token do GitHub. Digite e dê Enter.

Anote essa senha. Você vai usar ela no `sudo`.

### B2. Abrir o Ubuntu

Tecla Windows → digite **Ubuntu** → Enter. Esse é seu terminal Linux daqui em diante.

> No VS Code: instale a extensão **WSL** (da Microsoft), depois `Ctrl+Shift+P` → digite `WSL: Connect to WSL`. Aí o VS Code inteiro passa a trabalhar dentro do Linux.

### B3. Instalar o Miniconda (dentro do Ubuntu)

Cole no terminal do Ubuntu, uma linha por vez:

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
```

Vai aparecer um texto longo de licença: aperte `q` para sair dele, digite `yes` para aceitar, `Enter` para confirmar o local, e `yes` de novo no final.

Feche o terminal e abra de novo. Se aparecer `(base)` no começo da linha, funcionou.

> O Anaconda que você talvez já tenha no Windows **não serve** aqui. São sistemas separados. Instale de novo dentro do Ubuntu.

### B4. Trazer o projeto para dentro do Linux

**Não trabalhe na pasta do Windows.** O caminho `/mnt/c/Users/Vitor Takano/OneDrive/Área de Trabalho/...` tem espaços, acento e OneDrive sincronizando por cima — os três causam erro. Clone limpo:

```bash
cd ~
git clone https://github.com/1995pv/fastq-fetch.git
cd fastq-fetch
```

### B5. Criar o ambiente conda — **é aqui que entra**

```bash
conda env create -f environment.yml
conda activate fastq-fetch
```

O primeiro comando demora alguns minutos (baixa o SRA Toolkit inteiro). Você faz isso **uma vez só**.

O segundo você repete **toda vez que abrir um terminal novo**. Se aparecer `(fastq-fetch)` no começo da linha, está ativo. Se aparecer `(base)`, você esqueceu de ativar — e o script vai reclamar que falta `prefetch`.

### B6. Rodar

```bash
chmod +x fetch_fastq.sh
./fetch_fastq.sh -a SRR15829425 -o ./dados -t 4
```

---

## Onde ficam meus arquivos?

Os FASTQ baixados no WSL ficam dentro do Linux. Para abrir no Explorer do Windows, digite no terminal do Ubuntu:

```bash
explorer.exe .
```

Ou, no Explorer, digite `\\wsl$` na barra de endereço.

---

## Erros que você provavelmente vai ver

| Erro | Causa | Solução |
|---|---|---|
| `$'\r': command not found` | O arquivo foi salvo com quebra de linha do Windows (CRLF). | `sed -i 's/\r$//' fetch_fastq.sh` |
| `PackagesNotFoundError: sra-tools` | Você rodou o conda no Windows, não no WSL. | Faça a Rota B. |
| `Missing required command: 'prefetch'` | Esqueceu de ativar o ambiente. | `conda activate fastq-fetch` |
| `bash: ./fetch_fastq.sh: Permission denied` | Falta a marca de executável. | `chmod +x fetch_fastq.sh` |
| `conda: command not found` | Terminal aberto antes da instalação. | Feche e abra o terminal de novo. |
| `Permission to ... denied` / erro 403 no push | Token do GitHub sem o escopo `repo`. | Gere um token *classic* marcando a caixa `repo`. |
| `Password authentication is not supported` | Você digitou a senha do GitHub. | Use o Personal Access Token no lugar da senha. |
| `Activation of the selected Python environment is not supported in PowerShell` | Aviso da extensão Python do VS Code. | Irrelevante aqui. Clique em *Ignore*. |

---

## Resumo do fluxo diário (depois de tudo instalado)

```bash
# 1. abrir o Ubuntu
cd ~/fastq-fetch
conda activate fastq-fetch
./fetch_fastq.sh -a SRR1234567 -o ./dados
```

Três linhas. Todo o resto acima foi setup — feito uma vez só.
