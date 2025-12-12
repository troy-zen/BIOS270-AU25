#!/bin/bash

#SBATCH --job-name=flye_asm          # Name shown in squeue
#SBATCH --cpus-per-task=32           # Match threads passed to Flye
#SBATCH --mem=64G                    # Memory for the job
#SBATCH --time=02:00:00              # Max walltime (2 hours)
#SBATCH --partition=normal           # Partition/queue (change if your class uses a different one)
#SBATCH --output=logs/flye_%x_%j.out # Log file (inside Project1/logs)

# ====== USER ARGUMENTS ======
# We will pass sample name + FASTQ path from the command line:
#   sbatch run_flye.sbatch ecoli /path/to.fastq
#   sbatch run_flye.sbatch kpneu /path/to.fastq

SAMPLE_NAME="$1"  # e.g. "ecoli" or "kpneu"
FASTQ_PATH="$2"   # full path to the FASTQ file

# Basic safety checks
if [ -z "$SAMPLE_NAME" ] || [ -z "$FASTQ_PATH" ]; then
  echo "Usage: sbatch run_flye.sbatch <sample_name> <fastq_path>"
  exit 1
fi

if [ ! -f "$FASTQ_PATH" ]; then
  echo "ERROR: FASTQ file not found: $FASTQ_PATH"
  exit 1
fi

# ====== PATHS ======
# Root project folder (adjust if your repo path is different)
PROJECT_ROOT="/farmshare/user_data/$USER/repos/BIOS270-AU25/Project1"

# Output directory for this sample's Flye assembly
OUTDIR="${PROJECT_ROOT}/${SAMPLE_NAME}/flye_out"

# Ensure output + log directories exist
mkdir -p "$OUTDIR"
mkdir -p "${PROJECT_ROOT}/logs"

# Path to the bioinformatics container with Flye installed
BIOINFO_SIF="/farmshare/home/classes/bios/270/envs/bioinformatics_latest.sif"

# ====== RUN FLYE ======
echo "Running Flye for sample: $SAMPLE_NAME"
echo "FASTQ:  $FASTQ_PATH"
echo "OUTDIR: $OUTDIR"
echo "CPUs:   $SLURM_CPUS_PER_TASK"

apptainer run \
  -B /farmshare/home/classes/bios/270,/farmshare/user_data/$USER \
  "$BIOINFO_SIF" \
  flye \
    --nano-raw "$FASTQ_PATH" \
    --out-dir "$OUTDIR" \
    --threads "$SLURM_CPUS_PER_TASK"

echo "Flye finished for sample: $SAMPLE_NAME"
echo "Assembly should be at: ${OUTDIR}/assembly.fasta"
