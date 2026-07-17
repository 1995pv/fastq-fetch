# fastq-fetch

**Reproducible retrieval of public sequencing data — with integrity verification.**
*Download reprodutível de dados públicos de sequenciamento — com verificação de integridade.*

[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)](fetch_fastq.sh)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`fetch_fastq.sh` takes an accession, retrieves the corresponding FASTQ files from **ENA** or **SRA**, verifies every file against its published **MD5 checksum**, and emits an **nf-core compatible `samplesheet.csv`** ready for downstream pipelines.

> 🇧🇷 **Documentação em português:** [`docs/guia_pt.md`](docs/guia_pt.md) — guia introdutório, sem jargão, com glossário.
> 🇬🇧 **English documentation:** [`docs/guide_en.md`](docs/guide_en.md)
> 🪟 **No Windows?** [`docs/guia_windows.md`](docs/guia_windows.md) — setup completo via Git Bash ou WSL, com tabela de erros comuns.

---

## Why / Por quê

Downloading public sequencing data looks trivial until a transfer silently truncates a 40 GB file and the corruption only surfaces three analysis steps later. This script exists to make retrieval **verifiable and resumable**:

- ✅ **MD5 verification** on every downloaded file — corrupt transfers are detected and retried, not silently accepted.
- 🔁 **Resumable** — re-running skips files already present *and verified*; interrupted transfers continue where they stopped.
- 📋 **Auditable** — a timestamped log records every action.
- 📊 **Pipeline-ready** — outputs `samplesheet.csv` (`sample,fastq_1,fastq_2`), the standard entry format for nf-core workflows.
- 🔀 **Two sources** — ENA (pre-built FASTQ, faster) with fallback to SRA (NCBI).

---

## Installation

```bash
git clone https://github.com/1995pv/fastq-fetch.git
cd fastq-fetch
chmod +x fetch_fastq.sh
```

**Dependencies.** The ENA route needs only `curl`, `md5sum` and `awk` (present on most systems). The SRA route additionally requires SRA Toolkit:

```bash
conda env create -f environment.yml
conda activate fastq-fetch
```

or manually: `conda install -c bioconda sra-tools entrez-direct pigz`

> **Windows users:** bioconda has no Windows builds — the SRA route requires WSL. See [`docs/guia_windows.md`](docs/guia_windows.md).

---

## Usage

```bash
# Single run
./fetch_fastq.sh -a SRR1234567

# List of runs, 8 threads, custom output directory
./fetch_fastq.sh -i examples/accessions.txt -o ./data -t 8

# Entire BioProject (runs are resolved automatically)
./fetch_fastq.sh -p PRJNA123456 -o ./data

# Force the SRA route (for runs not mirrored on ENA)
./fetch_fastq.sh -a SRR1234567 -s sra -t 8
```

| Flag | Description | Default |
|------|-------------|---------|
| `-a` | single run accession (SRR/ERR/DRR) | — |
| `-i` | file with one accession per line | — |
| `-p` | project accession (PRJNA/PRJEB/PRJDB/SRP/ERP) | — |
| `-o` | output directory | `./fastq` |
| `-t` | threads | `4` |
| `-s` | source: `ena` or `sra` | `ena` |
| `-r` | retries per file | `3` |
| `-f` | force re-download | off |
| `-h` / `-v` | help / version | — |

Exactly one of `-a`, `-i`, `-p` is required.

---

## Output

```
data/
├── SRR1234567_1.fastq.gz            # reads (R1)
├── SRR1234567_2.fastq.gz            # reads (R2)
├── samplesheet.csv                  # sample,fastq_1,fastq_2
└── fetch_fastq_20260715_143022.log  # full audit log
```

**Exit codes:** `0` success · `1` usage/dependency error · `2` download or checksum failure.

---

## How it works

1. **Dependency check** — fails fast and explicitly rather than mid-transfer.
2. **Accession resolution** — a project accession is expanded into its runs via the ENA Portal API.
3. **Download** — with resume (`curl -C -`) and per-file retries.
4. **Integrity verification** — the recomputed MD5 is compared to the checksum published by the archive. Mismatch ⇒ discard and retry.
5. **Post-processing** — compression (`pigz`) and samplesheet generation.

On the SRA route, `vdb-validate` runs before `fasterq-dump`, so corruption is caught before it propagates.

---

## Roadmap

- [ ] Aspera (`ascp`) transfer support for large datasets
- [ ] Optional metadata fetch (library layout, platform, sample title)
- [ ] Automatic ENA → SRA fallback within a single run
- [ ] FastQC + MultiQC quality-control step

---

## License

MIT — see [LICENSE](LICENSE).

## Author

**Paulo Vitor Takano** — veterinarian (FMVZ/USP), veterinary clinical pathology, moving toward bioinformatics and data analysis in animal health.
[GitHub @1995pv](https://github.com/1995pv) · [LinkedIn](https://www.linkedin.com/in/paulo-vitor-t-aab54425a)
