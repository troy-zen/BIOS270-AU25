# Write-up 3: Data.md

**Name:** Troy Helenihi  
**Student ID:** troy430  
**Date:** 11/19/2025

---

## Overview


---

## Content


- Examine `create_bacteria_db.sh`, how many tables will be created in the database?  
>The script generates 3 tables corresponding to 3 different datasets.

- In the `insert_gff_table.py` script you submitted, explain the logic of using `try` and `except`. Why is this necessary?


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