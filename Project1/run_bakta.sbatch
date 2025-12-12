#!/bin/bash
#
# Run Bakta annotation on a Flye assembly
#
# Usage:
#   sbatch run_bakta.sbatch ecoli
#   sbatch run_bakta.sbatch kpneu

#SBATCH --job-name=bakta_annot
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --partition=normal
#SBATCH --output=logs/bakta_%x_%j.out

SAMPLE_NAME="$1"  # e.g. "ecoli" or "kpneu"

if [ -z "$SAMPLE_NAME" ]; then
  echo "Usage: sbatch run_bakta.sbatch <sample_name>"
  exit 1
fi

PROJECT_ROOT="/farmshare/user_data/$USER/repos/BIOS270-AU25/Project1"
ASSEMBLY="${PROJECT_ROOT}/${SAMPLE_NAME}/flye_out/assembly.fasta"
OUTDIR="${PROJECT_ROOT}/${SAMPLE_NAME}/bakta_out"

BAKTA_DB="/farmshare/home/classes/bios/270/data/archive/bakta_db/db"
BAKTA_SIF="/farmshare/home/classes/bios/270/envs/bakta_1.8.2--pyhdfd78af_0.sif"

# Basic checks
if [ ! -f "$ASSEMBLY" ]; then
  echo "ERROR: Assembly not found: $ASSEMBLY"
  exit 1
fi

mkdir -p "$OUTDIR"
mkdir -p "${PROJECT_ROOT}/logs"

echo "Running Bakta for sample: $SAMPLE_NAME"
echo "Assembly: $ASSEMBLY"
echo "Output:   $OUTDIR"

apptainer run \
  -B /farmshare/home/classes/bios/270,/farmshare/user_data/$USER \
  "$BAKTA_SIF" \
  bakta \
    --db "$BAKTA_DB" \
    --output "$OUTDIR" \
    "$ASSEMBLY" \
    --threads "$SLURM_CPUS_PER_TASK" \
    --force

echo "Bakta finished for sample: $SAMPLE_NAME"
echo "Key output: ${OUTDIR}/assembly.faa"
