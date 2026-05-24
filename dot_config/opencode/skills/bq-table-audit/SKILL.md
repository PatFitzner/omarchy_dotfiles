---
name: bq-table-audit
description: Audit one or more BigQuery tables or an entire dataset — reports size in GB, creation date, last modified date, last query user/timestamp, 180-day query count, and whether the table is referenced in the dbt project. Use when asked about table size, last queried, table age, table usage, dataset audit, or dbt coverage.
---

Project is always `gwkube`, region is always `EU` (`region-eu`).

Before running any `bq` commands, resolve the binary and ensure its directory is on PATH (so `gcloud`, which `bq` requires for auth, is also found):
```bash
BQ=$(command -v bq 2>/dev/null || find /usr /opt "$HOME" -name bq -type f 2>/dev/null | head -1)
SDK_BIN=$(dirname "$BQ")
export PATH="$SDK_BIN:$PATH"
```
Use `$BQ` in place of `bq` for all subsequent commands.

Audit BigQuery tables based on `$ARGUMENTS` and output results as CSV.

## Scope parsing

If `$ARGUMENTS` is empty, ask the user:
"Which table(s) or dataset do you want to audit?
- `dataset.table` — single table
- `dataset` — all tables in the dataset"

- Contains a `.` → single table audit
- No `.` → full dataset audit (enumerate all tables)

## Step 1 — Resolve the list of tables

**Single table:** use it directly.

**Full dataset:** list all tables:
```bash
$BQ ls --format=prettyjson gwkube:DATASET
```
Keep only entries where `type == "TABLE"`.

## Step 2 — Fetch metadata for each table

```bash
$BQ show --format=prettyjson gwkube:DATASET.TABLE
```

Extract per table:
- `numBytes` → `size_logical_gb` = numBytes / 1024³, 4 dp
- `numCurrentPhysicalBytes` → `size_physical_gb`, 4 dp
- `numRows`
- `numPartitions` (0 if absent)
- `creationTime` (epoch ms) → `YYYY-MM-DD HH:MM:SS` UTC
- `lastModifiedTime` (epoch ms) → `YYYY-MM-DD HH:MM:SS` UTC

## Step 3 — Fetch last query and 180-day query count per table (single INFORMATION_SCHEMA query)

Run once for the whole dataset:
```bash
$BQ query --nouse_legacy_sql \
  --project_id=gwkube --location=EU \
  "SELECT
     ref.table_id,
     COUNT(*) AS query_count_180d,
     MAX(creation_time) AS last_query_time,
     ARRAY_AGG(user_email ORDER BY creation_time DESC LIMIT 1)[OFFSET(0)] AS last_queried_by
   FROM \`region-eu.INFORMATION_SCHEMA.JOBS_BY_PROJECT\`,
     UNNEST(referenced_tables) AS ref
   WHERE state = 'DONE'
     AND creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 180 DAY)
     AND ref.project_id = 'gwkube'
     AND ref.dataset_id = 'DATASET'
   GROUP BY ref.table_id"
```

Join results to per-table metadata by `table_id`. Use `0` for `query_count_180d` and empty strings for user/time if no jobs found.

## Step 4 — Check dbt references

For each table, search the `./transformations` dbt project to find whether the table is referenced:

```bash
# Check if table_id appears as a dbt source or ref in any .sql or .yml file
grep -rl "TABLE_ID" ./transformations/models/ 2>/dev/null | head -5
```

Run `grep -rl "TABLE_ID" ./transformations/models/` for each table. A table is considered **referenced in dbt** if any `.sql` or `.yml` file mentions its name (as a source, ref, or direct table name). Record:
- `dbt_refs` — comma-separated list of **filenames** (basename only, no path) that reference the table. Empty string if none.
- `in_dbt` — `true` if any reference found, `false` otherwise.

You can also use dbt commands from the `./transformations` directory if needed (e.g. `cd transformations && uv run dbt ls`), but the grep approach is usually sufficient.

## Step 5 — Save and display CSV

Create `.tmp/` in the project root if it doesn't exist:
```bash
mkdir -p .tmp
```

Write the CSV to `.tmp/bq-audit-DATASET-YYYYMMDD_HHMMSS.csv` (using the current UTC timestamp). Header:

```
table,size_logical_gb,size_physical_gb,num_rows,num_partitions,created_at,last_modified_at,last_queried_by,last_queried_at,query_count_180d,in_dbt,dbt_refs
```

- `table` = `dataset.table_id`
- `last_queried_by` and `last_queried_at` = empty string if no job found in the 180-day window
- `query_count_180d` = integer count of distinct jobs referencing this table in the last 180 days (0 if none)
- `in_dbt` = `true` / `false`
- `dbt_refs` = comma-separated relative paths (quoted in CSV if non-empty)
- Sort rows by `table` ascending

Also write a Markdown file at the same path with `.md` extension (e.g. `.tmp/bq-audit-DATASET-YYYYMMDD_HHMMSS.md`). The Markdown file contains the same data as the CSV, rendered as a GitHub-flavored Markdown table with the same columns and row order, followed by the same summary lines:

```markdown
| table | size_logical_gb | size_physical_gb | num_rows | num_partitions | created_at | last_modified_at | last_queried_by | last_queried_at | query_count_180d | in_dbt | dbt_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| cdp.foo | 1.2345 | 0.2345 | 1000000 | 30 | 2024-01-01 00:00:00 | 2026-02-18 10:00:00 | user@example.com | 2026-02-18 09:00:00 | 42 | true | ./transformations/models/... |

# Saved to .tmp/bq-audit-cdp-20260218_073000.csv
# 12 tables audited — total logical: 45.32 GB, total physical: 8.14 GB
# 4 tables not referenced in dbt, 3 tables with 0 queries in last 180 days
```

Print the full CSV contents to stdout, then print the file paths and summary comment lines, e.g.:
```
# Saved to .tmp/bq-audit-cdp-20260218_073000.csv
# Saved to .tmp/bq-audit-cdp-20260218_073000.md
# 12 tables audited — total logical: 45.32 GB, total physical: 8.14 GB
# 4 tables not referenced in dbt, 3 tables with 0 queries in last 180 days
```
