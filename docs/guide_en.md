# A gentle guide: downloading sequencing data and getting FASTQ files

A jargon-free guide for people who have never worked with bioinformatics.
A **glossary** at the end explains every technical term (marked with ⭐).

> Quick command reference: [README](../README.md).

---

## First of all: what's the idea?

When a laboratory anywhere in the world performs the ⭐**sequencing** of an organism (a virus, a bacterium, an animal), it usually **deposits that data in public libraries on the internet**, so any researcher can reuse it.

Think of those libraries as a **giant digital archive**:

- Every dataset has a **catalogue code** (the ⭐**accession**), like the ISBN of a book.
- The "book" itself is a file called ⭐**FASTQ**: a very long text holding the "letters" of the genetic material (A, T, C, G).

What we do here is the equivalent of **walking into the library, pulling the right book by its code, and bringing a copy home** — while checking that no "page" went missing.

The `fetch_fastq.sh` script automates all of that.

---

## What you need before you start

A few "helper programs" must be installed. It's like needing a PDF reader before opening a PDF. The simplest way to install everything at once is a manager called ⭐**conda**:

```bash
conda env create -f environment.yml
conda activate fastq-fetch
```

> If you only use the simpler route (the "ENA", explained below), most computers already have what's needed (`curl`, `md5sum`, `awk`). The command above covers both routes.

---

## The two "routes"

The same data usually exists in **two different archives**. The script lets you choose:

| Route | Name | When to use | Analogy |
|-------|------|-------------|---------|
| **ENA** | European library | **Default. Start here.** Faster, because the file comes ready-made. | Taking the already-printed book off the shelf |
| **SRA** | American library (NCBI) | When the data only exists there. | Taking the manuscript and printing it yourself |

Nothing to memorise: the script uses **ENA** by default. If a file isn't there, it tells you to switch — just repeat the command adding `-s sra`.

---

## Step by step

### Step 1 — Allow the script to run

First time only. Think of it as "unlocking" the file:

```bash
chmod +x fetch_fastq.sh
```

### Step 2 — Find your code (accession)

You need to know **what** you want to download. There are two kinds of code:

- Starts with **SRR**, **ERR** or **DRR** → it's a ⭐**run** (one individual sample). **This is what becomes a FASTQ.**
- Starts with **PRJNA**, **PRJEB** or **SRP** → it's a ⭐**whole project** (many samples at once).

You find these codes in the scientific paper or on the archive's website.

### Step 3 — Run the command

**a) Download ONE sample:**
```bash
./fetch_fastq.sh -a SRR1234567
```
Reads as: *"download the sample (`-a`) with code SRR1234567"*.

**b) Download SEVERAL samples from a list:**

First create a text file with one code per line (see the template in `examples/accessions.txt`). Then:
```bash
./fetch_fastq.sh -i examples/accessions.txt -o ./my_data -t 8
```
Reads as: *"use the list (`-i`), save into the `my_data` folder (`-o`), and use 8 ⭐threads (`-t`) to go faster"*.

**c) Download a WHOLE project:**
```bash
./fetch_fastq.sh -p PRJNA123456 -o ./my_data
```
Reads as: *"take the whole project (`-p`) and figure out all of its samples on your own"*.

### Step 4 — Wait and check

The script prints what it's doing. When it finishes, your output folder contains:

- The **`.fastq.gz`** files → your data (`.gz` means ⭐compressed, to take up less space).
- A **`.log`** file → the "ship's log": everything that happened, with date and time. Useful when something goes wrong.
- A **`samplesheet.csv`** file → a **summary table** listing each sample and its files. It's the "entry form" for the analysis programs that come next.

---

## What the script does under the hood (no surprises)

You don't need this to use it — but it helps you trust the process. In order:

1. **Checks the helpers are installed.** If one is missing, it warns and stops, instead of failing halfway.
2. **Works out the sample list.** Given a whole project, it resolves every sample itself.
3. **Downloads each file.**
4. **Verifies integrity (the most important step).** Each file ships with a "fingerprint" called ⭐**MD5**. The script recomputes that fingerprint from the downloaded file and compares it to the original. If they match, the file arrived intact; if not, it discards and retries. This is the guarantee that **no data arrived corrupted**.
5. **Organises and compresses** the files and generates the summary table.

If your internet drops midway, just run it again: it **picks up where it stopped**, without re-downloading everything.

---

## How do I know it worked?

The script ends with a summary like `Succeeded: 3/3`. It also returns an **exit code**:

| Code | Meaning |
|------|---------|
| `0` | All good. |
| `1` | Usage error (wrong command) or a missing program. |
| `2` | Some sample failed to download or failed the MD5 check. |

If you get code `2`, the script lists which samples failed — usually you just retry those with the other route, `-s sra`.

---

## Glossary (⭐ terms)

**Sequencing** — The process of "reading" an organism's genetic material (DNA or RNA) and turning it into text: a long sequence of letters (A, T, C, G).

**FASTQ** — The file format holding that machine-read genetic text. Besides the letters, it stores a "confidence level" for each one. It's the end product we want.

**Accession** — The unique catalogue code of a dataset in a public archive, like a book's ISBN. E.g. `SRR1234567`.

**Run** — One sequencing "run": the data of **a single individual sample**. This is the level that actually becomes a FASTQ file. Codes: SRR, ERR, DRR.

**Project / BioProject** — An umbrella grouping **several samples** from the same study. Codes: PRJNA, PRJEB, SRP.

**ENA and SRA** — The two big public sequencing archives. ENA is European (ready-made files, faster); SRA is American (NCBI). They usually hold the same data.

**conda** — An "organised installer" for scientific software. It resolves everything a program needs to work.

**Thread** — A "worker" of the processor. Using more threads (`-t 8` = 8 workers) makes the computer split the job and finish sooner — provided your machine has the capacity.

**MD5 (checksum)** — A numeric "fingerprint" of a file. Used to check that the downloaded file is identical to the original, with nothing missing or corrupted.

**Compressed (.gz)** — A file "squeezed" to take less space and download faster, like a .zip. Analysis programs read `.gz` directly, no need to decompress.

**Log** — The script's "ship's log": a text file recording everything it did, with date and time. Where you look when something doesn't go as expected.

**Samplesheet** — A table (a .csv file, opens in Excel) summarising which files were downloaded for each sample. It's the organised input for the next analysis steps.

---

## In one sentence

> You give it a code; the script goes to the public library, brings back a verified copy of the genetic data, and leaves everything organised for the next step.
