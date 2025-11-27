# Data

Today, we’ll learn how to manage your data effectively with GCP, SQL database, and HDF5 data format.

>*"The dataset is too big to load..." - sighed by generations of grad students moments before their laptops crashed.*

## Resource 

[rclone](https://rclone.org/docs/)

## Setup

For this exercise, you'll need to forward port `53682` in addition to any usual port you specified for code-server/jupyter lab.
This allows `rclone` authentication. For example,

```bash
ssh -L 53682:localhost:53682 -L 23000:localhost:23000 <SUNetID>@login.farmshare.stanford.edu
```

### Google Cloud

Follow these steps to authenticate (`project-id` is the id of project `BIOS270` you created in `Setup.md`).

`gcloud` command is available in `bioinformatics_latest.sif` container

```
gcloud auth login
gcloud config set project <project-id>

gcloud auth application-default login
gcloud auth application-default set-quota-project <project-id>
```

### Google Cloud Storage (GCS)

On GCS, create a new `Bucket` named `bacteria`

On Farmshare, set up GCS remote using `rclone config` -> `New remote`
(`rclone` is available in `bioinformatics_latest.sif` container)

### Google Drive

On Farmshare, set up Drive remote using `rclone config` -> `New remote`

### Google BigQuery

On BigQuery, create a new `Dataset` named `bacteria`

---

## Dataset Overview

We will be working with a dataset containing approximately 2,000 annotated bacterial long-read assemblies. Such a dataset can inspire many biological questions. For example, How many proteins does a typical bacterium encode? or How conserved are proteins across species? However, exploring these questions directly from the raw data is inconvenient and inefficient.

To enable efficient querying, analysis, and future machine-learning applications, we will first convert the dataset into more suitable formats: an SQL database and an HDF5 file.


`/farmshare/home/classes/bios/270/data/bacteria` contains long-read assemblies (`*.fna`), annotations (`genomic.gff`), predicted protein sequences (`protein.faa`) of 1958 bacteria isolates.

`/farmshare/home/classes/bios/270/data/bacteria_supp` contains a metadata file containing information on each assembly (`assembly_data_report.jsonl`) and [`mmseqs2`](https://github.com/soedinglab/MMseqs2) clustering output of all proteins predicted from 1958 bacteria isolates (`clusters_mmseqclust_id03_c08.tsv`)

`/farmshare/home/classes/bios/270/data/protein_data/` contains protein embeddings (in batches of 10,000) of all predicted proteins in 1958 isolates. Protein embeddings are vector representations of protein sequences - proteins that are similar in sequence or structure are expected to have more similar embeddings


---

## Database

### 1. Create a Local SQL Database

Submit the script `create_bacteria_db.sh` as a Slurm job to create a local SQLite database named `bacteria.db`.

```bash
sbatch create_bacteria_db.sh
```

While the job is running, answer the following questions:

- Examine `create_bacteria_db.sh`, how many tables will be created in the database?
> There will be 3 tables created corresponding to the 3 python scripts.

- In the `insert_gff_table.py` script you submitted, explain the logic of using `try` and `except`. Why is this necessary?
> The `try`/`except` block is used to safely write each GFF DataFrame into the SQLite database, which can only handle one writer at a time. When multiple processes try to write to the same `bacteria.db` file simultaneously, SQLite will raise an error saying the database is locked. This means that another process is currently writing, and if we wait a moment, the lock will clear. \
\
>Inside the loop `try` attempts to write the DataFrame into the SQL table. If it succeeds, it will `break` out of the retry loop. If the database is currently locked, it will catch the error, wait one second to give it time to unlock, and then try again. If the error is something else, it will raise it immediately and stop trying because retrying won't fix a real bug.

```python
while try_num < max_retries:
    try_num += 1
    try:
        df.to_sql(gff_table_name, conn, if_exists="append", index=False)
        break
    except (pd.errors.DatabaseError, sqlite3.OperationalError) as e:
        if "database is locked" in str(e):
            logging.info(f"Database is locked, retrying {try_num}/{max_retries}")
            time.sleep(1)
        else:
            raise e
```

After the database has been created, use `rclone copy` to copy the output `bacteria.db` to your `bacteria` bucket on `GCS` and a dedicated folder on `Drive`.

---

### 2. Query the Created Database

Complete the `TODO` sections in `query_bacteria_db.py`. You may want to examine the `gff2df` function in `insert_gff_table.py` to understand the columns in `gff` table.

Then, run `query_bacteria_db.py`

```bash
python query_bacteria_db.py --database_path <path to the bacteria.db created in Section 1>
```

Record the runtime. You may stop the session early if it takes too long and only record the runtime of the first few iterations.

Then, uncomment `db.index_record_ids()` in `query_bacteria_db.py` and note how the runtime changes.  
Why do you think this is the case?
>Without an index, SQLite has to scan the entire gff table every time we ask for a `protein_id` for a specific `record_id`. Since the script repeats this query for every `record_id`, the program ends up doing thousands of full table scans, which is very slow.\
\
When we add an index with `db.index_record_ids`, SQLite creates a fast lookup structure that lets it jump directly to the matching rows instead of searching the whole table. This removes the repeated full scans and makes each query much faster, which dramatically reduces the overall runtime.
---

### 3. Upload to Google BigQuery

The dataset you are handling is relatively small. However, for larger datasets or collaborative access, uploading to **Google BigQuery** is a practical approach.

Examine the `upload_bigquery.py` script.  
Explain the role of `CHUNK_SIZE` and why it is necessary:
>`CHUNK_SIZE` lets the script process the table in manageable batches by reading N rows, uploading to BigQuery, and repeating. This keeps memory usage controlled and makes the upload scalable to much larger datasets.
```python
df = pd.read_sql_query(
    f"SELECT * FROM {table} LIMIT {CHUNK_SIZE} OFFSET {offset}",
    conn
)
```

Once your dataset has been uploaded, create a query on BigQuery that involves at least **two tables** from the dataset.  
Export the query results as a **CSV file** to **GCS**.

---

### 4. HDF5 Data

Review the `create_protein_h5.sh` and `create_protein_h5.py` scripts.  
Make sure you understand their functionality. You won't need to run these scripts as they take a few hours to complete.

Explain why the following chunk configuration makes sense - what kind of data access pattern is expected, and why does this align with biological use cases?

```python
chunk_size = 1000
chunks = (chunk_size, n_features)
```
>Protein embeddings are stored as a large matrix, where each row is one protein and each column is one of the 164 embedding features. In most biological analyses, data is accessed in groups (e.g. all proteins from a record or all proteins from an assembly) rather than one protein at a time.\
\
>Setting the chunk shape to `(1000, n_features)` means the file stores the data in blocks of 1,000 proteins. This matches how the data is used in large consecutive slices that are read at once. Chunking the dataset in this way makes those group reads faster and reduces overhead, because HDF5 can load entire blocks efficiently instead of doing lots of small random accesses.

---

### 5. Practice – Combining SQL and HDF5

For this exercise, use data from `/farmshare/home/classes/bios/270/data/processed_bacteria_data`

Write a Python script that 
- reads in `bacteria.db` and `protein_embeddings.h5`
- takes a `record id` and `metric` (either `mean` or `mean_mid`) as input params
- outputs the corresponding protein embeddings **matrix** with shape `(N, D)`, where:

    - `N` = number of protein IDs in the record  
    - `D` = embedding dimension (164)

Save the resulting matrix as a `.npy` file.

**Hints:**
- You may import classes and functions from `query_bacteria_db.py`.
- Consider creating a **dictionary** mapping between protein IDs and their indices in h5 dataset to avoid repeated lookups using `list.index()`.
