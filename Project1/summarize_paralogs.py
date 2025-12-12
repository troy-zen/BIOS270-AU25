#!/usr/bin/env python3
"""
summarize_paralogs.py

Summarize paralogous proteins from:
  - Bakta protein FASTA (assembly.faa)
  - MMseqs2 cluster TSV (*_cluster.tsv)

Usage (example for ecoli):

  apptainer run \
    -B /farmshare/home/classes/bios/270,/farmshare/user_data/$USER \
    /farmshare/home/classes/bios/270/envs/bioinformatics_latest.sif \
    python summarize_paralogs.py \
      --faa /farmshare/user_data/$USER/repos/BIOS270-AU25/Project1/ecoli/bakta_out/assembly.faa \
      --clusters /farmshare/user_data/$USER/repos/BIOS270-AU25/Project1/ecoli/mmseqs_out/ecoli_prot90_cluster.tsv \
      --out-tsv /farmshare/user_data/$USER/repos/BIOS270-AU25/Project1/ecoli/results/ecoli_paralogs.tsv \
      --out-png /farmshare/user_data/$USER/repos/BIOS270-AU25/Project1/ecoli/results/ecoli_paralogs_top10.png
"""

import argparse
from collections import defaultdict
import matplotlib.pyplot as plt


def parse_args():
    parser = argparse.ArgumentParser(description="Summarize protein paralogs from MMseqs2 clusters.")
    parser.add_argument("--faa", required=True, help="Protein FASTA file from Bakta (assembly.faa).")
    parser.add_argument("--clusters", required=True, help="MMseqs2 *_cluster.tsv file.")
    parser.add_argument("--out-tsv", required=True, help="Output TSV file: protein_id, protein_name, copy_number.")
    parser.add_argument("--out-png", required=True, help="Output PNG for bar plot of top 10 paralogs.")
    return parser.parse_args()


def parse_faa_headers(faa_path):
    """
    Build a mapping: protein_id -> protein_name from FASTA headers.

    Assumes headers like:
      >protein_id description blah blah

    protein_id  = first token after '>'
    protein_name = rest of the header (may be empty)
    """
    id_to_name = {}
    with open(faa_path) as f:
        for line in f:
            if line.startswith(">"):
                header = line[1:].strip()
                parts = header.split(None, 1)
                protein_id = parts[0]
                if len(parts) > 1:
                    protein_name = parts[1]
                else:
                    protein_name = ""
                id_to_name[protein_id] = protein_name
    return id_to_name


def parse_clusters(cluster_path):
    """
    Build cluster_id -> list of protein_ids from MMseqs *_cluster.tsv.

    File format:
      cluster_id<TAB>protein_id
    """
    cluster_to_proteins = defaultdict(list)
    with open(cluster_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            cluster_id, protein_id = line.split("\t")
            cluster_to_proteins[cluster_id].append(protein_id)
    return cluster_to_proteins


def main():
    args = parse_args()

    # 1) protein_id -> protein_name
    protein_name_map = parse_faa_headers(args.faa)

    # 2) cluster_id -> [protein_ids]
    cluster_to_proteins = parse_clusters(args.clusters)

    # 3) Compute copy number for proteins in clusters with >1 member (paralogs)
    protein_copy_number = {}
    for cluster_id, proteins in cluster_to_proteins.items():
        if len(proteins) <= 1:
            continue  # singleton cluster, not a paralog
        copy_num = len(proteins)
        for pid in proteins:
            protein_copy_number[pid] = copy_num

    # 4) Write summary TSV
    out_dir = "/".join(args.out_tsv.split("/")[:-1])
    if out_dir:
        import os
        os.makedirs(out_dir, exist_ok=True)

    with open(args.out_tsv, "w") as out:
        out.write("protein_id\tprotein_name\tcopy_number\n")
        for pid, copy_num in sorted(
            protein_copy_number.items(),
            key=lambda x: x[1],
            reverse=True
        ):
            pname = protein_name_map.get(pid, "")
            out.write(f"{pid}\t{pname}\t{copy_num}\n")

    # 5) Plot top 10 paralogs
    if not protein_copy_number:
        print("No paralogous clusters found (no clusters with >1 protein).")
        return

    # Sort proteins by copy number desc and take top 10
    top = sorted(
        protein_copy_number.items(),
        key=lambda x: x[1],
        reverse=True
    )[:10]

    ids = [pid for pid, _ in top]
    copies = [cn for _, cn in top]

    plt.figure(figsize=(10, 6))
    plt.bar(range(len(ids)), copies)
    plt.xticks(range(len(ids)), ids, rotation=45, ha="right")
    plt.ylabel("Copy number")
    plt.title("Top 10 most frequent paralogous proteins")
    plt.tight_layout()

    out_png_dir = "/".join(args.out_png.split("/")[:-1])
    if out_png_dir:
        import os
        os.makedirs(out_png_dir, exist_ok=True)

    plt.savefig(args.out_png, dpi=300)
    plt.close()

    print(f"Wrote TSV: {args.out_tsv}")
    print(f"Wrote PNG: {args.out_png}")


if __name__ == "__main__":
    main()
