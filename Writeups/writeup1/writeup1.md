# Write-up 1: Setup

**Name:** Troy Helenihi  
**Student ID:** troy430  
**Date:** 11/16/2025

---

## Overview

This section documents the steps I completed to configure my working environment for BIOS 270 using the instructions in Setup.md. It covers the customization of my Bash profile, setup of tools for managing workflows and data, installation of key utilities such as micromamba, Docker Desktop, Nextflow, and GPU-related platforms, and the warm-up SLURM exercise. Along the way, I recorded key observations and screenshots to demonstrate that each tool was installed correctly and that my environment is prepared for the computational workflows ahead in the course.

---

## Content
Here contains the screenshots, code snippets, and observations for documentation of work completed from the `Setup.md` and `Environment.md` instructions.

### `Setup.md` documentation
---
**Bash profile configuration:**
```bash
# Added paths and aliases for quicker navigation:
export SCRATCH="/farmshare/user_data/troy430"
export BIOS_REPO="/farmshare/user_data/troy430/repos/BIOS270-AU25"
export WRITEUP="/farmshare/user_data/troy430/repos/BIOS270-AU25/Writeup"
alias cdscr="cd $SCRATCH"
alias cdfork="cd $BIOS_REPO"
alias cdw="cd $WRITEUP"
# Helper function to start agent and add key
ghagent() {
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519_farmshare_troy-zen
  ssh -T git@github.com
}
```

Installed **micromamba** (location can be seen in command line):

<img src=./images/micromamba_path_version.png width="750" alt="micromamba directory and version">


Installed **Docker Desktop**:

<img src=./images/docker_account.png width="750" alt="Docker Hub homepage">

Activated **GCP** free trial on personal account:

<img src=./images/gcp_account.png width="750" alt="GCP account homepage">


Installed **Nextflow**:
```bash
troy430@rice-03:/farmshare/user_data/troy430$ nextflow info
  Version: 25.10.0 build 10289
  Created: 22-10-2025 16:26 UTC 
  System: Linux 6.14.0-27-generic
  Runtime: Groovy 4.0.28 on OpenJDK 64-Bit Server VM 21.0.8+9-Ubuntu-0ubuntu124.04.1
  Encoding: UTF-8 (UTF-8)
```
Opted for **Colab Pro** as free trial accounts on GCP cannot request increased GPU quota:

<img src=./images/google_colab_pro.png width="750" alt="Colab Pro homepage">


Created a **Weights & Biases** account to track my ML training metrics and experiment logs:

<img src=./images/wandb.png width="750" alt="wandb homepage">


### SLURM warmup answers to questions in Setup.md

**1. How many slurm jobs will be submitted?**
> Three SLURM jobs will be submitted because the directive `#SBATCH --array=0-2` creates jobs with indices 0, 1, and 2.

**2. What is the purpose of the `if` statement?**
> The purpose of the `if` statement is to evenly split the work across the three SLURM jobs by having each one process only the lines of `data.txt` whose line numbers **match** its array index (based on the modulo result).

**3. What is the expected output in each `*.out` file?**

*Each job’s output file contains the line numbers and values from `data.txt` that correspond to its array index:*

- **Job 0 (`SLURM_ARRAY_TASK_ID=0`)**
```python
0: 12
3: 8
```
- **Job 1 (`SLURM_ARRAY_TASK_ID=1`)**
```python
1: 7
4: 27
```
- **Job 2 (`SLURM_ARRAY_TASK_ID=2`)**
```python
2: 91
5: 30
```
Each file is saved as `logs/warmup_<jobID>_<arrayIndex>.out`.

---
## Acknowledgement
Collaborator: Eliel Akinbami - helped clarify instructions for customizing my Bash profile.