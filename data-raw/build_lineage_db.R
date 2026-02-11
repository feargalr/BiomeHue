## build_lineage_db.R
## Maintainer-only script to build the internal lineage database from NCBI taxdump.
## NOT shipped with the package. Run manually when updating the database.
##
## Usage: source("data-raw/build_lineage_db.R")
##
## Requires internet access. Downloads ~140MB, processes to ~500KB compressed.
## NOTE: base R download.file() may time out on the 140MB file.
##       If so, download manually with curl:
##       curl -L -o /tmp/new_taxdump.tar.gz \
##         https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.tar.gz

# --- Configuration ---
taxdump_url <- "https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.tar.gz"
temp_dir <- tempdir()
archive_path <- file.path(temp_dir, "new_taxdump.tar.gz")
output_path <- file.path("data", "lineage_db.rda")

# --- Download ---
if (!file.exists(archive_path)) {
  message("Downloading NCBI new_taxdump (~140MB)...")
  download.file(taxdump_url, archive_path, mode = "wb", timeout = 300)
}

# --- Extract needed files ---
message("Extracting rankedlineage.dmp and nodes.dmp...")
untar(archive_path, files = c("rankedlineage.dmp", "nodes.dmp"), exdir = temp_dir)
lineage_file <- file.path(temp_dir, "rankedlineage.dmp")
nodes_file   <- file.path(temp_dir, "nodes.dmp")

if (!file.exists(lineage_file)) stop("rankedlineage.dmp not found")
if (!file.exists(nodes_file))   stop("nodes.dmp not found")

# --- Parse nodes.dmp for true ranks ---
# rankedlineage.dmp does NOT contain the rank of each entry — its lineage
# columns list parent taxa, not the entry itself. A genus like "Akkermansia"
# has genus="" and family="Akkermansiaceae" because those columns refer to
# ancestors. We need nodes.dmp to get the actual rank.
message("Parsing nodes.dmp for ranks...")
nodes_raw    <- readLines(nodes_file)
nodes_parsed <- strsplit(nodes_raw, "\t\\|\t?", perl = TRUE)
nodes_taxid  <- sapply(nodes_parsed, `[`, 1)
nodes_rank   <- trimws(sapply(nodes_parsed, `[`, 3))
rank_lookup  <- setNames(nodes_rank, nodes_taxid)
message(sprintf("  Loaded ranks for %d tax_ids", length(rank_lookup)))

# --- Parse rankedlineage.dmp ---
message("Parsing rankedlineage.dmp (this may take a minute)...")
raw <- readLines(lineage_file)
message(sprintf("  Read %d lines", length(raw)))

# rankedlineage.dmp format (tab-pipe-tab delimited):
# tax_id | tax_name | species | genus | family | order | class | phylum | kingdom | superkingdom
parsed <- strsplit(raw, "\t\\|\t?", perl = TRUE)

lineage_raw <- data.frame(
  tax_id       = sapply(parsed, `[`, 1),
  tax_name     = trimws(sapply(parsed, `[`, 2)),
  species      = trimws(sapply(parsed, `[`, 3)),
  genus        = trimws(sapply(parsed, `[`, 4)),
  family       = trimws(sapply(parsed, `[`, 5)),
  order        = trimws(sapply(parsed, `[`, 6)),
  class        = trimws(sapply(parsed, `[`, 7)),
  phylum       = trimws(sapply(parsed, `[`, 8)),
  kingdom      = trimws(sapply(parsed, `[`, 9)),
  superkingdom = trimws(sapply(parsed, `[`, 10)),
  stringsAsFactors = FALSE
)

# Clean trailing pipe from last column
lineage_raw$superkingdom <- gsub("\\s*\\|\\s*$", "", lineage_raw$superkingdom)

message(sprintf("  Parsed %d total entries", nrow(lineage_raw)))

# --- Assign true rank from nodes.dmp ---
lineage_raw$rank <- rank_lookup[lineage_raw$tax_id]

# --- Filter to Bacteria, Archaea, Fungi ---
message("Filtering to Bacteria, Archaea, and Fungi...")
keep <- lineage_raw$superkingdom %in% c("Bacteria", "Archaea") |
  lineage_raw$kingdom == "Fungi"
lineage_filtered <- lineage_raw[keep, ]
message(sprintf("  %d entries after kingdom filter", nrow(lineage_filtered)))

message("  Rank distribution (top 10):")
print(head(sort(table(lineage_filtered$rank), decreasing = TRUE), 10))

# --- Keep genus-level and above (drop species to save space) ---
message("Dropping species-level entries...")
lineage_compact <- lineage_filtered[lineage_filtered$rank != "species", ]
message(sprintf("  %d entries after dropping species", nrow(lineage_compact)))

# --- Build final database ---
lineage_db <- data.frame(
  Name         = lineage_compact$tax_name,
  Rank         = lineage_compact$rank,
  Genus        = lineage_compact$genus,
  Family       = lineage_compact$family,
  Order        = lineage_compact$order,
  Class        = lineage_compact$class,
  Phylum       = lineage_compact$phylum,
  Superkingdom = ifelse(lineage_compact$kingdom == "Fungi", "Fungi",
                        lineage_compact$superkingdom),
  stringsAsFactors = FALSE
)

# Remove entries with empty phylum (not useful for colour assignment)
lineage_db <- lineage_db[nchar(lineage_db$Phylum) > 0, ]

# Deduplicate by Name
lineage_db <- lineage_db[!duplicated(lineage_db$Name), ]

message(sprintf("\nFinal database: %d entries", nrow(lineage_db)))

# Verify key taxa
message("Verification of known genera:")
for (t in c("Akkermansia", "Prevotella", "Bacteroides", "Lactobacillus",
            "Bifidobacterium", "Escherichia", "Streptococcus", "Candida",
            "Saccharomyces", "Methanobrevibacter")) {
  idx <- match(t, lineage_db$Name)
  if (!is.na(idx)) {
    message(sprintf("  %-20s Rank=%-12s Phylum=%s", t,
                    lineage_db$Rank[idx], lineage_db$Phylum[idx]))
  }
}

message("\nPhylum distribution (top 20):")
phylum_counts <- sort(table(lineage_db$Phylum), decreasing = TRUE)
print(head(phylum_counts, 20))
message(sprintf("Total unique phyla: %d", length(phylum_counts)))
message("Superkingdom distribution:")
print(table(lineage_db$Superkingdom))

# --- Save ---
message(sprintf("\nSaving to %s with xz compression...", output_path))
save(lineage_db, file = output_path, compress = "xz")

file_size <- file.size(output_path)
message(sprintf("Done! File size: %.1f KB", file_size / 1024))
message(sprintf("Build date: %s", Sys.Date()))

# --- Cleanup ---
unlink(lineage_file)
unlink(nodes_file)

message("Lineage database build complete.")
