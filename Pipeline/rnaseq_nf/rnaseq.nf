// RNA-seq QC → Trim Galore → Salmon + DESeq2 (from CSV samplesheet)
// Expect a CSV with columns: sample,read1,read2,condition
// No intermediate samples.csv is generated; DESeq2 infers quant.sf paths
// from --outdir/<sample>/salmon_outs/quant.sf
nextflow.enable.dsl=2

include { FASTQC } from './modules/qc/fastqc.nf'
include { TRIMGALORE } from './modules/qc/trimgalore.nf'
include { SALMON } from './modules/pseudoalign/salmon.nf'
include { DESEQ2 } from './modules/diffexp/deseq2.nf'

// Build a Salmon index from a reference transcriptome FASTA
process SALMON_INDEX {
    tag "salmon_index"

    input:
        path transcriptome

    output:
        path "salmon_index"

    """
    salmon index \
        -t ${transcriptome} \
        -i salmon_index
    """
}


// -------------------- Channels --------------------
def samplesheet_ch = Channel
  .fromPath(params.samplesheet)
  .ifEmpty { error "Missing --samplesheet file: ${params.samplesheet}" }

samples_ch = samplesheet_ch.splitCsv(header:true).map { row ->
    tuple(row.sample.trim(), file(row.read1.trim(), absolute: true), file(row.read2.trim(), absolute:true), row.condition.trim())
}


// -------------------- Workflow --------------------

workflow {
    // 1) Run QC and trimming as before
    FASTQC(samples_ch)
    trimmed_ch = TRIMGALORE(samples_ch)
    // quant_ch   = SALMON(trimmed_ch, params.index)
    // 2) Decide how to obtain the Salmon index
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

    // 3) Run Salmon using trimmed reads + index channel
    quant_ch = SALMON(trimmed_ch, index_ch)

    // 4) DESeq2 as before (unchanged)
    if( params.run_deseq ) {

        // Collect all Salmon outputs into a map {sample: quant_path}
        quant_paths_ch = quant_ch
            .map { sample, quant, cond -> "${sample},${quant}" }
            .collectFile(
                name: "quant_paths.csv",
                newLine: true,
                seed: "sample,quant_path"  // header line
            )

        DESEQ2(quant_paths_ch, samplesheet_ch)
    }
}

workflow.onComplete {
    log.info "Pipeline finished. Results in: ${params.outdir}"
}