#!/bin/bash
#SBATCH --job-name=createdb
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err
#SBATCH --array=0-4
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=04:00:00

# Make sure logs dir exists
mkdir -p logs

# Adjust this path to wherever your repo actually is
REPO_DIR=/scratch/users/$USER/repos/BIOS270-AU25
SIF=${REPO_DIR}/Environment/bioinformatics_latest.sif
DATA_DIR=${REPO_DIR}/Data
DATABASE="${DATA_DIR}/bacteria.db"

# Command to run things INSIDE the container
RUN="apptainer run \
  -B /farmshare/user_data/$USER,/farmshare/home/classes/bios/270,/scratch/users/$USER \
  ${SIF}"

cd "$DATA_DIR"

$RUN python insert_gff_table.py --database_path "$DATABASE"
$RUN python insert_protein_cluster_table.py --database_path "$DATABASE"
$RUN python insert_metadata_table.py --database_path "$DATABASE"