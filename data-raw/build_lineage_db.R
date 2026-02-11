## build_lineage_db.R
## Maintainer-only script to build the internal lineage database from NCBI taxdump.
## NOT shipped with the package. Run manually when updating the database.
##
## Usage: source("data-raw/build_lineage_db.R")
##
## Requires internet access. Downloads ~300MB, processes to ~200KB compressed.

# --- Configuration ---
taxdump_url <- "https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.tar.gz"
temp_dir <- tempdir()
archive_path <- file.path(temp_dir, "new_taxdump.tar.gz")
output_path <- file.path("data", "lineage_db.rda")

# --- Download ---
message("Downloading NCBI new_taxdump...")
download.file(taxdump_url, archive_path, mode = "wb")

# --- Extract rankedlineage.dmp ---
message("Extracting rankedlineage.dmp...")
untar(archive_path, files = "rankedlineage.dmp", exdir = temp_dir)
lineage_file <- file.path(temp_dir, "rankedlineage.dmp")

if (!file.exists(lineage_file)) {
  stop("rankedlineage.dmp not found after extraction")
}

# --- Parse ---
message("Parsing rankedlineage.dmp (this may take a minute)...")
raw <- readLines(lineage_file)
message(sprintf("  Read %d lines", length(raw)))

# rankedlineage.dmp format (tab-pipe-tab delimited):
# tax_id | tax_name | species | genus | family | order | class | phylum | kingdom | superkingdom
# We split on \t|\t pattern
parsed <- strsplit(raw, "\t\\|\t?", perl = TRUE)

# Build data frame
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

# --- Filter to Bacteria, Archaea, Fungi ---
message("Filtering to Bacteria, Archaea, and Fungi...")
keep <- lineage_raw$superkingdom %in% c("Bacteria", "Archaea") |
  lineage_raw$kingdom == "Fungi"
lineage_filtered <- lineage_raw[keep, ]
message(sprintf("  %d entries after kingdom filter", nrow(lineage_filtered)))

# --- Determine rank for each entry ---
# If species column is non-empty, it's species level
# If genus is non-empty but species is empty, it's genus level
# etc.
determine_rank <- function(species, genus, family, order, class, phylum) {
  ifelse(nchar(species) > 0, "species",
    ifelse(nchar(genus) > 0, "genus",
      ifelse(nchar(family) > 0, "family",
        ifelse(nchar(order) > 0, "order",
          ifelse(nchar(class) > 0, "class",
            ifelse(nchar(phylum) > 0, "phylum", "other"))))))
}

lineage_filtered$rank <- with(lineage_filtered,
  determine_rank(species, genus, family, order, class, phylum))

message("  Rank distribution:")
print(table(lineage_filtered$rank))

# --- Keep genus-level and above (drop species to save space) ---
message("Keeping genus-level and above...")
lineage_compact <- lineage_filtered[lineage_filtered$rank != "species", ]
message(sprintf("  %d entries after dropping species", nrow(lineage_compact)))

# --- Build final database ---
# For each entry, we want: Name, Rank, Phylum, Superkingdom
# The "Name" should be the most specific non-empty taxonomic name
get_name <- function(tax_name, genus, family, order, class, phylum, rank) {
  # tax_name is the actual NCBI name for this entry
  tax_name
}

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

# Remove entries with empty phylum (not useful for color assignment)
lineage_db <- lineage_db[nchar(lineage_db$Phylum) > 0, ]

# Deduplicate by Name
lineage_db <- lineage_db[!duplicated(lineage_db$Name), ]

message(sprintf("Final database: %d entries", nrow(lineage_db)))
message("  Phylum distribution (top 20):")
phylum_counts <- sort(table(lineage_db$Phylum), decreasing = TRUE)
print(head(phylum_counts, 20))
message(sprintf("  Total unique phyla: %d", length(phylum_counts)))

# --- Save ---
message(sprintf("Saving to %s with xz compression...", output_path))
save(lineage_db, file = output_path, compress = "xz")

file_size <- file.size(output_path)
message(sprintf("Done! File size: %.1f KB", file_size / 1024))
message(sprintf("Build date: %s", Sys.Date()))

# --- Cleanup ---
unlink(archive_path)
unlink(lineage_file)

message("Lineage database build complete.")
