# Suppress R CMD check NOTE for lazy-loaded data
utils::globalVariables("lineage_db")

# --- Session cache environment ---
.biomeHue_cache <- new.env(parent = emptyenv())

#' @keywords internal
.init_cache <- function() {
  if (!exists("lineages", envir = .biomeHue_cache)) {
    assign("lineages", list(), envir = .biomeHue_cache)
  }
}

#' @keywords internal
.get_cached <- function(taxon) {
  .init_cache()
  cache <- get("lineages", envir = .biomeHue_cache)
  cache[[taxon]]
}

#' @keywords internal
.set_cached <- function(taxon, info) {
  .init_cache()
  cache <- get("lineages", envir = .biomeHue_cache)
  cache[[taxon]] <- info
  assign("lineages", cache, envir = .biomeHue_cache)
}

# --- Name normalization ---

#' @keywords internal
.normalize_taxon_name <- function(taxon) {
  # Strip QIIME-style prefixes: k__, p__, c__, o__, f__, g__, s__
  name <- sub("^[kpcofgs]__", "", taxon)
  # Convert underscores to spaces
  name <- gsub("_", " ", name)
  # Trim whitespace
  name <- trimws(name)
  name
}

#' @keywords internal
.extract_genus <- function(taxon) {
  # Take first word (genus from binomial)
  parts <- strsplit(taxon, "\\s+")[[1]]
  if (length(parts) >= 1) parts[1] else taxon
}

#' @keywords internal
.is_unclassified <- function(taxon) {
  lc <- tolower(taxon)
  lc %in% c("other", "unclassified", "unknown", "unassigned", "na", "") ||
    grepl("^unclassified", lc) ||
    grepl("^unknown", lc) ||
    grepl("^uncultured", lc)
}

# --- Internal database lookup ---

#' @keywords internal
.lookup_lineage_internal <- function(taxon_clean) {
  db <- lineage_db

  # Exact match (case-insensitive)
  idx <- match(tolower(taxon_clean), tolower(db$Name))
  if (!is.na(idx)) {
    return(list(
      phylum       = db$Phylum[idx],
      rank         = db$Rank[idx],
      superkingdom = db$Superkingdom[idx]
    ))
  }

  # Try genus extraction for species-level names
  genus <- .extract_genus(taxon_clean)
  if (genus != taxon_clean) {
    idx <- match(tolower(genus), tolower(db$Name))
    if (!is.na(idx)) {
      return(list(
        phylum       = db$Phylum[idx],
        rank         = "species_inferred",
        superkingdom = db$Superkingdom[idx]
      ))
    }
  }

  # Not found
  list(phylum = NA_character_, rank = NA_character_, superkingdom = NA_character_)
}

# --- NCBI API lookup ---

#' @keywords internal
.query_ncbi_lineage <- function(taxon) {
  result <- tryCatch({
    # Step 1: search for taxonomy ID
    search_url <- paste0(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=taxonomy&term=",
      utils::URLencode(taxon, reserved = TRUE),
      "&retmode=xml"
    )
    con <- url(search_url, open = "rt")
    on.exit(close(con), add = TRUE)
    xml_text <- readLines(con, warn = FALSE)
    close(con)
    on.exit(NULL)

    # Extract tax_id
    id_lines <- grep("<Id>", xml_text, value = TRUE)
    if (length(id_lines) == 0) return(NULL)
    tax_id <- gsub(".*<Id>(\\d+)</Id>.*", "\\1", id_lines[1])

    # Rate limit
    Sys.sleep(0.34)

    # Step 2: fetch full lineage
    fetch_url <- paste0(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id=",
      tax_id, "&retmode=xml"
    )
    con2 <- url(fetch_url, open = "rt")
    on.exit(close(con2), add = TRUE)
    xml_text2 <- readLines(con2, warn = FALSE)
    close(con2)
    on.exit(NULL)

    xml_full <- paste(xml_text2, collapse = "\n")

    # Extract lineage ranks from <LineageEx>
    # Each taxon in lineage has <ScientificName> and <Rank>
    phylum <- .extract_rank_from_xml(xml_full, "phylum")
    rank_line <- grep("<Rank>", xml_text2, value = TRUE)
    # Get the rank of the queried taxon itself (last <Rank> outside LineageEx)
    taxon_rank <- gsub(".*<Rank>(.*)</Rank>.*", "\\1", utils::tail(rank_line, 1))

    # Determine superkingdom
    superkingdom <- .extract_rank_from_xml(xml_full, "superkingdom")
    if (is.na(superkingdom)) {
      # Check if it's in Fungi (kingdom level)
      kingdom <- .extract_rank_from_xml(xml_full, "kingdom")
      if (!is.na(kingdom) && kingdom == "Fungi") superkingdom <- "Fungi"
    }

    if (!is.na(phylum)) {
      list(phylum = phylum, rank = taxon_rank, superkingdom = superkingdom)
    } else {
      NULL
    }
  }, error = function(e) {
    NULL
  })

  result
}

#' @keywords internal
.extract_rank_from_xml <- function(xml_text, target_rank) {
  # Find the rank in <LineageEx> blocks
  # Pattern: <Rank>target_rank</Rank> preceded by <ScientificName>X</ScientificName>
  pattern <- paste0(
    "<ScientificName>([^<]+)</ScientificName>\\s*<Rank>",
    target_rank, "</Rank>"
  )
  m <- regmatches(xml_text, regexpr(pattern, xml_text, perl = TRUE))
  if (length(m) > 0 && nchar(m) > 0) {
    gsub(".*<ScientificName>([^<]+)</ScientificName>.*", "\\1", m)
  } else {
    NA_character_
  }
}

# --- Orchestrator ---

#' @keywords internal
get_lineage <- function(taxon, use_ncbi = TRUE) {
  # Handle unclassified
  if (.is_unclassified(taxon)) {
    return(list(
      phylum       = "Unclassified",
      rank         = "unclassified",
      superkingdom = NA_character_
    ))
  }

  # Normalize
  taxon_clean <- .normalize_taxon_name(taxon)

  # Check cache
  cached <- .get_cached(taxon_clean)
  if (!is.null(cached)) return(cached)

  # Internal database

  info <- .lookup_lineage_internal(taxon_clean)

  # NCBI fallback
  if (is.na(info$phylum) && use_ncbi) {
    message(sprintf("  Looking up '%s' via NCBI...", taxon_clean))
    ncbi_result <- .query_ncbi_lineage(taxon_clean)
    if (!is.null(ncbi_result)) {
      info <- ncbi_result
    } else {
      warning(sprintf("Could not resolve lineage for '%s'", taxon),
              call. = FALSE)
    }
  }

  # Cache result
  .set_cached(taxon_clean, info)

  info
}
