#!/bin/bash
#
# Run MMseqs2 easy-cluster on Bakta protein FASTA
#
# Usage:
#   sbatch run_mmseqs.sbatch ecoli
#   sbatch run_mmseqs.sbatch kpneu

#SBATCH --job-name=mmseqs_cluster
#SBATCH --cpus-per-task=32
#SBATCH --mem=8G
#SBATCH --time=00:30:00
#SBATCH --partition=normal
#SBATCH --output=logs/mmseqs_%x_%j.out

SAMPLE_NAME="$1"  # e.g. "ecoli" or "kpneu"

if [ -z "$SAMPLE_NAME" ]; then
  echo "Usage: sbatch run_mmseqs.sbatch <sample_name>"
  exit 1
fi

PROJECT_ROOT="/farmshare/user_data/$USER/repos/BIOS270-AU25/Project1"

FAA="${PROJECT_ROOT}/${SAMPLE_NAME}/bakta_out/assembly.faa"
OUTDIR="${PROJECT_ROOT}/${SAMPLE_NAME}/mmseqs_out"

BIOINFO_SIF="/farmshare/home/classes/bios/270/envs/bioinformatics_latest.sif"

if [ ! -f "$FAA" ]; then
  echo "ERROR: Protein FASTA not found: $FAA"
  echo "Did Bakta finish for sample $SAMPLE_NAME?"
  exit 1
fi

mkdir -p "$OUTDIR"
mkdir -p "${PROJECT_ROOT}/logs"

echo "Running MMseqs2 for sample: $SAMPLE_NAME"
echo "Input proteins: $FAA"
echo "Output dir:     $OUTDIR"

apptainer run \
  -B /farmshare/home/classes/bios/270,/farmshare/user_data/$USER \
  "$BIOINFO_SIF" \
  mmseqs easy-cluster \
    "$FAA" \
    "${OUTDIR}/${SAMPLE_NAME}_prot90" \
    "${OUTDIR}/tmp" \
    --min-seq-id 0.9 \
    -c 0.8 \
    --cov-mode 1 \
    -s 7 \
    --threads "$SLURM_CPUS_PER_TASK"

echo "MMseqs2 finished for sample: $SAMPLE_NAME"
echo "Cluster file should be: ${OUTDIR}/${SAMPLE_NAME}_prot90_cluster.tsv"
