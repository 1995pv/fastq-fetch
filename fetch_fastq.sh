#!/usr/bin/env bash
#
# fetch_fastq.sh - Download public sequencing data (FASTQ) from ENA or SRA
#                  with MD5 integrity verification and samplesheet output.
#
# Author : Paulo Vitor Takano
# License: MIT
#
set -euo pipefail

VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"

# ---------------------------------------------------------------- defaults ---
OUTDIR="./fastq"
THREADS=4
SOURCE="ena"          # ena | sra
ACCESSION=""
INPUT_LIST=""
PROJECT=""
RETRIES=3
FORCE=0
LOGFILE=""

# ------------------------------------------------------------------ colors ---
if [[ -t 2 ]]; then
    C_RED=$'\033[31m'; C_YEL=$'\033[33m'; C_GRN=$'\033[32m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
    C_RED=""; C_YEL=""; C_GRN=""; C_DIM=""; C_OFF=""
fi

# ---------------------------------------------------------------- logging ----
_ts() { date '+%Y-%m-%d %H:%M:%S'; }

log()  { printf '%s [INFO ] %s\n'  "$(_ts)" "$*" | tee -a "${LOGFILE:-/dev/null}" >&2; }
warn() { printf '%s [WARN ] %s%s%s\n' "$(_ts)" "$C_YEL" "$*" "$C_OFF" | tee -a "${LOGFILE:-/dev/null}" >&2; }
ok()   { printf '%s [ OK  ] %s%s%s\n' "$(_ts)" "$C_GRN" "$*" "$C_OFF" | tee -a "${LOGFILE:-/dev/null}" >&2; }
die()  { printf '%s [ERROR] %s%s%s\n' "$(_ts)" "$C_RED" "$*" "$C_OFF" | tee -a "${LOGFILE:-/dev/null}" >&2; exit 1; }

# ------------------------------------------------------------------ usage ----
usage() {
cat <<EOF
$SCRIPT_NAME v$VERSION — download FASTQ files from ENA/SRA with checksum verification.

USAGE:
  $SCRIPT_NAME -a SRR1234567
  $SCRIPT_NAME -i accessions.txt -o ./data -t 8
  $SCRIPT_NAME -p PRJNA123456 -o ./data

INPUT (choose exactly one):
  -a <accession>   Single run accession (SRR/ERR/DRR).
  -i <file>        Text file with one run accession per line.
  -p <project>     Project accession (PRJNA/PRJEB/PRJDB/SRP/ERP) — all runs are resolved.

OPTIONS:
  -o <dir>         Output directory.               (default: $OUTDIR)
  -t <int>         Threads for decompression/dump. (default: $THREADS)
  -s <ena|sra>     Download source.                (default: $SOURCE)
  -r <int>         Retries per file.               (default: $RETRIES)
  -f               Force re-download of existing files.
  -h               Show this help and exit.
  -v               Show version and exit.

OUTPUT:
  <outdir>/*.fastq.gz      the sequencing reads
  <outdir>/samplesheet.csv sample,fastq_1,fastq_2 (nf-core compatible)
  <outdir>/fetch_fastq_<timestamp>.log  full run log

EXIT CODES:
  0 success | 1 usage/dependency error | 2 download or checksum failure
EOF
}

# ----------------------------------------------------------- dependencies ----
need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: '$1'. Install it (see README) and try again."
}

check_deps() {
    need_cmd curl
    need_cmd md5sum
    need_cmd awk
    if [[ "$SOURCE" == "sra" ]]; then
        need_cmd prefetch
        need_cmd fasterq-dump
        need_cmd vdb-validate
    fi
    if command -v pigz >/dev/null 2>&1; then
        GZIP_CMD="pigz -p $THREADS"
    elif command -v gzip >/dev/null 2>&1; then
        GZIP_CMD="gzip"
        if [[ "$SOURCE" == "sra" ]]; then
            warn "pigz not found — falling back to gzip (slower)."
        fi
    else
        die "Neither pigz nor gzip found."
    fi
    return 0
}

# ------------------------------------------------------- accession parsing ---
is_run_accession()     { [[ "$1" =~ ^[SED]RR[0-9]+$ ]]; }
is_project_accession() { [[ "$1" =~ ^(PRJ(NA|EB|DB)[0-9]+|[SED]RP[0-9]+)$ ]]; }

ENA_API="https://www.ebi.ac.uk/ena/portal/api/filereport"

# Resolve a project accession into its list of run accessions (via ENA API).
resolve_project() {
    local prj="$1" tsv
    log "Resolving runs for project $prj via ENA portal API..."
    tsv="$(curl -fsSL --retry "$RETRIES" \
            "${ENA_API}?accession=${prj}&result=read_run&fields=run_accession&format=tsv" \
          || die "Could not query ENA API for $prj. Check the accession and your connection.")"
    local runs
    runs="$(printf '%s\n' "$tsv" | awk 'NR>1 && NF {print $1}')"
    [[ -z "$runs" ]] && die "No runs found for project $prj."
    log "Found $(printf '%s\n' "$runs" | wc -l | tr -d ' ') run(s)."
    printf '%s\n' "$runs"
}

# ------------------------------------------------------------ downloading ----
# Download one file with resume support and verify its MD5.
download_and_verify() {
    local url="$1" expected_md5="$2" dest="$3"
    local attempt=1

    if [[ -s "$dest" && $FORCE -eq 0 ]]; then
        if [[ -n "$expected_md5" ]] && verify_md5 "$dest" "$expected_md5"; then
            ok "$(basename "$dest") already present and verified — skipping."
            return 0
        fi
        warn "$(basename "$dest") exists but failed verification — re-downloading."
        rm -f "$dest"
    fi

    while (( attempt <= RETRIES )); do
        log "Downloading $(basename "$dest") (attempt $attempt/$RETRIES)..."
        if curl -fL --retry 2 --retry-delay 5 -C - -o "$dest" "$url"; then
            if [[ -z "$expected_md5" ]]; then
                warn "No MD5 published for $(basename "$dest") — integrity NOT verified."
                return 0
            fi
            if verify_md5 "$dest" "$expected_md5"; then
                ok "$(basename "$dest") downloaded and MD5 verified."
                return 0
            fi
            warn "MD5 mismatch for $(basename "$dest") — discarding and retrying."
            rm -f "$dest"
        else
            warn "Transfer failed for $(basename "$dest")."
        fi
        attempt=$((attempt + 1))
        sleep 3
    done
    return 1
}

verify_md5() {
    local file="$1" expected="$2" actual
    actual="$(md5sum "$file" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]]
}

# Fetch one run from ENA (pre-made FASTQ files + published MD5s).
fetch_from_ena() {
    local run="$1" tsv ftp_field md5_field
    tsv="$(curl -fsSL --retry "$RETRIES" \
            "${ENA_API}?accession=${run}&result=read_run&fields=run_accession,fastq_ftp,fastq_md5&format=tsv" \
          || { warn "ENA API query failed for $run."; return 1; })"

    ftp_field="$(printf '%s\n' "$tsv" | awk -F'\t' 'NR==2 {print $2}')"
    md5_field="$(printf '%s\n' "$tsv" | awk -F'\t' 'NR==2 {print $3}')"

    if [[ -z "${ftp_field// }" ]]; then
        warn "$run has no FASTQ on ENA. It may be SRA-only — retry with: -s sra"
        return 1
    fi

    local -a urls md5s
    IFS=';' read -r -a urls <<< "$ftp_field"
    IFS=';' read -r -a md5s <<< "$md5_field"

    local i url dest
    for i in "${!urls[@]}"; do
        url="${urls[$i]}"
        [[ "$url" != http* && "$url" != ftp* ]] && url="https://${url}"
        dest="${OUTDIR}/$(basename "${urls[$i]}")"
        download_and_verify "$url" "${md5s[$i]:-}" "$dest" || return 1
    done
    return 0
}

# Fetch one run from SRA (download .sra, validate, then dump to FASTQ).
fetch_from_sra() {
    local run="$1"
    log "prefetch $run ..."
    prefetch --max-size 100G -O "${OUTDIR}/.sra_tmp" "$run" >>"$LOGFILE" 2>&1 \
        || { warn "prefetch failed for $run."; return 1; }

    log "vdb-validate $run ..."
    vdb-validate "${OUTDIR}/.sra_tmp/${run}" >>"$LOGFILE" 2>&1 \
        || { warn "vdb-validate failed for $run — data may be corrupt."; return 1; }

    log "fasterq-dump $run ..."
    fasterq-dump --split-files --threads "$THREADS" \
        --temp "${OUTDIR}/.sra_tmp" -O "$OUTDIR" "${OUTDIR}/.sra_tmp/${run}" >>"$LOGFILE" 2>&1 \
        || { warn "fasterq-dump failed for $run."; return 1; }

    log "Compressing $run FASTQ files..."
    local f
    for f in "${OUTDIR}/${run}"*.fastq; do
        [[ -e "$f" ]] || continue
        $GZIP_CMD -f "$f"
    done

    rm -rf "${OUTDIR}/.sra_tmp/${run}"
    ok "$run retrieved from SRA."
    return 0
}

# ------------------------------------------------------------ samplesheet ----
write_samplesheet() {
    local sheet="${OUTDIR}/samplesheet.csv"
    local run r1 r2 single
    echo "sample,fastq_1,fastq_2" > "$sheet"
    for run in "${SUCCESSFUL[@]}"; do
        r1="${OUTDIR}/${run}_1.fastq.gz"
        r2="${OUTDIR}/${run}_2.fastq.gz"
        single="${OUTDIR}/${run}.fastq.gz"
        if [[ -s "$r1" && -s "$r2" ]]; then
            echo "${run},$(readlink -f "$r1"),$(readlink -f "$r2")" >> "$sheet"
        elif [[ -s "$single" ]]; then
            echo "${run},$(readlink -f "$single")," >> "$sheet"
        elif [[ -s "$r1" ]]; then
            echo "${run},$(readlink -f "$r1")," >> "$sheet"
        else
            warn "No FASTQ found on disk for $run — omitted from samplesheet."
        fi
    done
    ok "Samplesheet written: $sheet"
}

# ------------------------------------------------------------------- main ----
main() {
    while getopts ":a:i:p:o:t:s:r:fhv" opt; do
        case "$opt" in
            a) ACCESSION="$OPTARG" ;;
            i) INPUT_LIST="$OPTARG" ;;
            p) PROJECT="$OPTARG" ;;
            o) OUTDIR="$OPTARG" ;;
            t) THREADS="$OPTARG" ;;
            s) SOURCE="$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')" ;;
            r) RETRIES="$OPTARG" ;;
            f) FORCE=1 ;;
            h) usage; exit 0 ;;
            v) echo "$SCRIPT_NAME v$VERSION"; exit 0 ;;
            \?) usage; die "Unknown option: -$OPTARG" ;;
            :)  usage; die "Option -$OPTARG requires an argument." ;;
        esac
    done

    # --- validate input selection
    local n_inputs=0
    [[ -n "$ACCESSION"  ]] && (( n_inputs++ )) || true
    [[ -n "$INPUT_LIST" ]] && (( n_inputs++ )) || true
    [[ -n "$PROJECT"    ]] && (( n_inputs++ )) || true
    if (( n_inputs != 1 )); then
        usage
        die "Provide exactly one of: -a <run>, -i <list file>, -p <project>."
    fi
    [[ "$SOURCE" == "ena" || "$SOURCE" == "sra" ]] || die "Invalid source '$SOURCE' (use 'ena' or 'sra')."
    [[ "$THREADS" =~ ^[0-9]+$ && "$THREADS" -gt 0 ]] || die "Threads (-t) must be a positive integer."
    [[ "$RETRIES" =~ ^[0-9]+$ && "$RETRIES" -gt 0 ]] || die "Retries (-r) must be a positive integer."

    mkdir -p "$OUTDIR"
    LOGFILE="${OUTDIR}/fetch_fastq_$(date '+%Y%m%d_%H%M%S').log"
    : > "$LOGFILE"

    log "$SCRIPT_NAME v$VERSION starting | source=$SOURCE | threads=$THREADS | outdir=$OUTDIR"
    check_deps

    # --- build run list
    local -a RUNS=()
    if [[ -n "$ACCESSION" ]]; then
        is_run_accession "$ACCESSION" || die "'$ACCESSION' is not a valid run accession (expected SRR/ERR/DRR). For a project use -p."
        RUNS=("$ACCESSION")
    elif [[ -n "$INPUT_LIST" ]]; then
        [[ -f "$INPUT_LIST" ]] || die "List file not found: $INPUT_LIST"
        local line
        while IFS= read -r line || [[ -n "$line" ]]; do
            line="$(echo "$line" | tr -d '[:space:]')"
            [[ -z "$line" || "$line" == \#* ]] && continue
            is_run_accession "$line" || die "Invalid accession in $INPUT_LIST: '$line'"
            RUNS+=("$line")
        done < "$INPUT_LIST"
        [[ ${#RUNS[@]} -eq 0 ]] && die "No valid accessions found in $INPUT_LIST."
    else
        is_project_accession "$PROJECT" || die "'$PROJECT' is not a valid project accession (expected PRJNA/PRJEB/PRJDB/SRP/ERP)."
        mapfile -t RUNS < <(resolve_project "$PROJECT")
    fi

    log "Queued ${#RUNS[@]} run(s) for download."

    # --- download loop
    SUCCESSFUL=()
    local -a FAILED=()
    local run idx=0
    for run in "${RUNS[@]}"; do
        idx=$((idx + 1))
        log "${C_DIM}[${idx}/${#RUNS[@]}]${C_OFF} Processing $run"
        if [[ "$SOURCE" == "ena" ]]; then
            if fetch_from_ena "$run"; then SUCCESSFUL+=("$run"); else FAILED+=("$run"); fi
        else
            if fetch_from_sra "$run"; then SUCCESSFUL+=("$run"); else FAILED+=("$run"); fi
        fi
    done

    rm -rf "${OUTDIR}/.sra_tmp"

    # --- report
    [[ ${#SUCCESSFUL[@]} -gt 0 ]] && write_samplesheet
    log "----------------------------------------"
    ok  "Succeeded: ${#SUCCESSFUL[@]}/${#RUNS[@]}"
    if [[ ${#FAILED[@]} -gt 0 ]]; then
        warn "Failed: ${FAILED[*]}"
        warn "Tip: if the source was ENA, some runs may exist only on SRA — retry those with -s sra"
        log  "Log saved to $LOGFILE"
        exit 2
    fi
    log "Log saved to $LOGFILE"
}

main "$@"
