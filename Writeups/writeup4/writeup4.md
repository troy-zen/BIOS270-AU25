# Write-up 4: Pipeline.md - Nextflow

**Name:** Troy Helenihi  
**Student ID:** troy430  
**Date:** 11/28/2025

---

## Overview
In this assignment, I worked with both SLURM and Nextflow to understand how multi-stage RNA-seq pipelines are coordinated on a cluster. On the SLURM side, I examined how parallel per-sample jobs (FASTQC → Trim Galore → Salmon) are chained together using job dependencies, and how a final DESeq2 step can be triggered only after all Salmon quantification jobs finish.

On the Nextflow side, I configured and ran a full DSL2 pipeline using Singularity containers. I added logic that allows the workflow to either use an existing Salmon index or build one automatically when only a transcriptome FASTA is provided. After updating the config files and running the workflow on SLURM, the pipeline produced the complete set of outputs—from QC reports through DESeq2 differential expression results.

---

## Content

### SLURM Pipeline Question
*How could one add a differential expression analysis (DESeq2) step to the `rnaseq_pipeline_array_depend.sh` script such that DESeq2 runs only after all salmon jobs for all samples have completed? (No code required - describe conceptually)*

>To add a DESeq2 step that only runs after all Salmon jobs finish, you could extend the SLURM script to:
>1) Capture the job ID of each salmon job as it is submitted.
>- When you call `sbatch` for the Salmon step, SLURM returns a job ID. You save that ID in the `SALMON_QUANT` variable for that iteration of the loop
>2) Store each of these Salmon job IDs in a list/array (e.g. `SALMON_JOBS`) as you loop over samples.
>- As the script iterates over samples and submits one Salmon job per sample, you append each returned job ID into an in-script array. By the end of the loop, this array holds the job IDs for *all* Salmon quantification jobs.
>3) Submit a single DESeq2 job that depends on all of those Salmon jobs:
>- Build a string that includes includes every Salmon job ID (e.g. `id1:id2:id3:...`)
>- Then use it in the dependency:
>```bash
>--dependency=afterok:id1:id2:id3:...
>```
In following these steps, the script launches all Salmon jobs first, records their job IDs, and then submits a single DESeq2 job whose `afterok` dependency points at every Salmon job. SLURM handles the synchronization automatically, ensuring DESeq2 only runs once all Salmon quantifications are finished and available.

--
### Nextflow SALMON_INDEX (YAML and rnaseq.nf)

Salmon requires an index directory to quantify reads. In the original Nextflow pipeline, the index was assumed to already exist. To make the pipeline more flexible, we add a `SALMON_INDEX` process so the workflow behaves accordingly depending on user-supplied parameters:
>**1) Case 1 — User provides an existing index**
>
>If `params.index` is set in `params.yaml`, the pipeline should:
        >- use that directory directly as the Salmon input
        >- skip the indexing step entirely
>
>**2) Case 2 — User does NOT provide an index, but provides a transcriptome FASTA**
>
>If `params.index` is missing but `params.transcriptome` is provided:
        >- run the new SALMON_INDEX process
        >- generate a new index from the transcriptome using `salmon index`
        >- pass the resulting index directory to the downstream `SALMON` process
>
>**3) Case 3 — Neither index nor transcriptome is provided**
>
>The pipeline cannot run Salmon without an index or a FASTA file to build one.
    >In this case, the workflow must:
        >- stop immediately
        >- print an informative error message explaining what is missing

Resulting pipeline:
```groovy
def index_ch

    if (params.index) {
        // Case 1: user provided a prebuilt index
        log.info "Using existing Salmon index: ${params.index}"
        index_ch = Channel.value( file(params.index) )
    
    } else if (params.transcriptome) {
        // Case 2: no index, but transcriptome is provided → build index
        log.info "No index provided; building Salmon index from transcriptome: ${params.transcriptome}"

        def transcriptome_ch = Channel.value( file(params.transcriptome) )
        index_ch = SALMON_INDEX(transcriptome_ch)

    } else {
         // Case 3: neither index nor transcriptome is provided → fail fast
        log.error """
        ERROR: You must provide either:
          - 'index' (path to prebuilt Salmon index directory), or
          - 'transcriptome' (reference transcriptome FASTA file)
        in configs/params.yaml
        """
        System.exit(1)
    }
```
--
### Running the Nextflow Pipeline
To execute the RNA-seq workflow using containers and SLURM, I needed to adjust **two** configuration files:
1) `nextflow.config`
    - Set `runOptions` to bind my `$SCRATCH` and `$CLASS` directories into the container
    - Specified a local `cacheDir` for storing Singularity images so they don’t need to be repulled every run:
        ```groovy
        cacheDir = '/farmshare/user_data/troy430/repos/BIOS270-AU25/Pipeline/rnaseq_nf/envs/containers'
        ```
2) `params.yaml`
    - Set `outdir` to a newly created directory for processed data within my `$SCRATCH` directory:
        ```yaml
        outdir: '/farmshare/user_data/troy430/bios270/data/processed_data/SRP628437_nf'
        ```
Before running, I ensured that the scripts in `rnaseq_nf/bin/` were executable and that the `nextflow` binary was in my `$PATH`:
```bash
# cd to ./Pipeline
chmod +x ./rnaseq_nf/bin/*
```

Then I launched the workflow inside `tmux` with:
```bash
# cd rnaseq_nf
nextflow run rnaseq.nf -params-file configs/params.yaml -c configs/nextflow.config -profile slurm -resume
```

Nextflow submitted jobs to SLURM, pulled the required Singularity image once, and executed the full RNA-seq workflow from QC to DESeq2. One nice thing I learned was how Nextflow had the ability to automatically **resume** where you left off in the workflow, meaning you don't have to restart from beginning.

--

### Troubleshooting Summary

During the setup and launch of the Nextflow pipeline, two issues arose:

1) Nextflow config parsing error:
    - The initial `nextflow.config` contained `#` comments, which are not valid in Groovy-based config files.
    - Replacing them with `//` resolved the error.

2) Singularity not found in PATH
    - The pipeline initially failed to pull the container image because `singularity`/`apptainer` was not loaded in my environment.
    - Running `module load apptainer` before launching Nextflow fixed this simple issue.

These fixes ensured the container environment was properly initialized and allowed the pipeline to run successfully on SLURM.

---



