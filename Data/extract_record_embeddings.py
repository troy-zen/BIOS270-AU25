import argparse       
import numpy as np   
import h5py           

from query_bacteria_db import BacteriaDatabase


def parse_args():
    """
    Handle command-line arguments:
    --database_path, --h5_path, --record_id, --metric, --output_path
    """
    parser = argparse.ArgumentParser()

    parser.add_argument("--database_path", type=str, required=True)
    parser.add_argument("--h5_path", type=str, default="/farmshare/home/classes/bios/270/data/processed_bacteria_data/protein_embeddings.h5")
    parser.add_argument("--record_id", type=str, required=True)
    parser.add_argument(
        "--metric",
        type=str,
        choices=["mean_embeddings", "mean_mid_embeddings"],
        required=True,
    )
    parser.add_argument(
        "--output_path",
        type=str,
        default="embeddings.npy",
    )

    return parser.parse_args()


def build_id_to_index_map(h5_file):
    """
    Read the protein_ids dataset from the HDF5 file
    and build a dictionary: protein_id -> row index.
    """
    protein_ids_ds = h5_file["protein_ids"]   # HDF5 1D dataset

    # Convert the dataset into a normal Python list of strings
    protein_ids = [
        pid.decode("utf-8") if isinstance(pid, bytes) else str(pid)
        for pid in protein_ids_ds[:]
    ]

    # Build a dictionary: protein_id -> index
    id_to_idx = {pid: i for i, pid in enumerate(protein_ids)}
    return id_to_idx


def extract_embeddings_for_record(database_path, h5_path, record_id, metric):
    """
    Core logic:
    1. Get protein_ids for the given record_id from bacteria.db.
    2. Open HDF5 file.
    3. Map protein_id -> row index in embeddings.
    4. Collect embeddings for all proteins in this record_id.
    5. Return an (N, 164) numpy array.
    """
    # 1) Get protein IDs using your BacteriaDatabase helper
    db = BacteriaDatabase(database_path)
    protein_ids = db.get_protein_ids_from_record_id(record_id)
    db.close()

    # Remove any None entries just in case
    protein_ids = [pid for pid in protein_ids if pid is not None]

    if len(protein_ids) == 0:
        raise ValueError(f"No protein IDs found for record_id '{record_id}'")

    # 2) Open the HDF5 embeddings file
    with h5py.File(h5_path, "r") as h5f:
        # Build the protein_id -> index map
        id_to_idx = build_id_to_index_map(h5f)

        # Select the correct embedding dataset
        if metric not in h5f:
            raise KeyError(
                f"Metric '{metric}' not found in HDF5. "
                f"Available datasets: {list(h5f.keys())}"
            )

        emb_ds = h5f[metric]  # e.g., shape (total_proteins, 164)

        # 3) Find indices for this record's proteins
        indices = []
        for pid in protein_ids:
            if pid in id_to_idx:
                indices.append(id_to_idx[pid])
            # else: silently skip proteins that have no embedding

        if len(indices) == 0:
            raise ValueError(
                f"No embeddings found for proteins in record_id '{record_id}'"
            )

        # 4) Convert list of indices to numpy array
        indices = np.array(indices, dtype=np.int64)

        # 5) Use fancy indexing to grab all embeddings at once
        embeddings = emb_ds[indices, :]  # (N, 164)

    return embeddings


if __name__ == "__main__":
    # This block runs only when you call:
    # python3 extract_record_embeddings.py ...
    args = parse_args()

    embeddings = extract_embeddings_for_record(
        database_path=args.database_path,
        h5_path=args.h5_path,
        record_id=args.record_id,
        metric=args.metric,
    )

    np.save(args.output_path, embeddings)

    print(f"Saved embeddings to {args.output_path}")
    print(f"Matrix shape: {embeddings.shape}")
