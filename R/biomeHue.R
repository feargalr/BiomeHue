#' Generate HCL-based colours for microbiome taxa
#'
#' Generates colours for microbiome taxa based on their taxonomic lineage
#' using the HCL colour space. Colours are assigned systematically by phylum,
#' with variation in hue, luminance and chroma to distinguish related taxa.
#'
#' Lineage is resolved by: (1) checking an internal NCBI-derived database,
#' (2) extracting genus from species binomials and retrying, (3) optionally
#' querying the NCBI Entrez API for unknown taxa.
#'
#' @param taxa Character vector of taxon names (genus, species, family, etc.).
#'   Supports underscores (Bacteroides_fragilis), spaces, and QIIME-style
#'   prefixes (g__Bacteroides).
#' @param use_ncbi Logical. If TRUE (default), query the NCBI API for taxa
#'   not found in the internal database. Set to FALSE for offline use.
#' @param return_lineage Logical. If TRUE, return a data frame with colours
#'   and lineage info. If FALSE (default), return a named character vector.
#'
#' @return If \code{return_lineage = FALSE}: a named character vector of
#'   hex colour codes. If \code{return_lineage = TRUE}: a data frame with
#'   columns Taxon, Colour, Phylum, Rank, Superkingdom.
#'
#' @examples
#' # Basic usage
#' biomeHue(c("Bacteroides", "Faecalibacterium", "Bifidobacterium"),
#'          use_ncbi = FALSE)
#'
#' # With lineage information
#' biomeHue(c("Akkermansia", "Prevotella"), use_ncbi = FALSE,
#'          return_lineage = TRUE)
#'
#' \donttest{
#' # With NCBI lookup for unknown taxa
#' biomeHue(c("Bacteroides", "SomeRareTaxon"))
#' }
#'
#' @export
biomeHue <- function(taxa, use_ncbi = TRUE, return_lineage = FALSE) {

  if (!is.character(taxa)) {
    stop("taxa must be a character vector")
  }

  if (length(taxa) == 0) {
    if (return_lineage) {
      return(data.frame(
        Taxon = character(0), Colour = character(0),
        Phylum = character(0), Rank = character(0),
        Superkingdom = character(0), stringsAsFactors = FALSE
      ))
    }
    return(character(0))
  }

  # Preserve original names for output, deduplicate for processing
  taxa_unique <- unique(taxa)

  # Resolve lineages
  lineage_info <- lapply(taxa_unique, function(taxon) {
    get_lineage(taxon, use_ncbi = use_ncbi)
  })
  names(lineage_info) <- taxa_unique

  # Generate colours
  colors <- .generate_color_palette(taxa_unique, lineage_info)

  if (return_lineage) {
    data.frame(
      Taxon        = taxa_unique,
      Colour       = unname(colors),
      Phylum       = vapply(lineage_info, function(x) {
                       if (is.na(x$phylum)) "Unknown" else x$phylum
                     }, character(1)),
      Rank         = vapply(lineage_info, function(x) {
                       if (is.na(x$rank)) "unknown" else x$rank
                     }, character(1)),
      Superkingdom = vapply(lineage_info, function(x) {
                       if (is.na(x$superkingdom)) "Unknown" else x$superkingdom
                     }, character(1)),
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  } else {
    colors
  }
}


#' View the BiomeHue colour palette
#'
#' Returns a sample of taxa from the internal lineage database with
#' their auto-generated colours, useful for previewing phylum colour schemes.
#'
#' @param phylum Optional character vector of phylum names to filter by.
#'   If NULL (default), returns taxa from all phyla.
#' @param n Maximum number of taxa to return per phylum. Default 5.
#'
#' @return A data frame with columns Taxon, Colour, Phylum, Rank, Superkingdom.
#'
#' @examples
#' # Preview all phyla
#' biomeHue_palette(n = 3)
#'
#' # Preview specific phyla
#' biomeHue_palette(phylum = c("Bacillota", "Bacteroidota"))
#'
#' @export
biomeHue_palette <- function(phylum = NULL, n = 5) {
  db <- lineage_db

  if (!is.null(phylum)) {
    db <- db[db$Phylum %in% phylum, ]
  }

  if (nrow(db) == 0) {
    return(data.frame(
      Taxon = character(0), Colour = character(0),
      Phylum = character(0), Rank = character(0),
      Superkingdom = character(0), stringsAsFactors = FALSE
    ))
  }

  # Sample n genera per phylum
  phyla <- unique(db$Phylum)
  genera_only <- db[db$Rank == "genus", ]
  if (nrow(genera_only) == 0) genera_only <- db

  sampled <- do.call(rbind, lapply(phyla, function(p) {
    rows <- genera_only[genera_only$Phylum == p, ]
    if (nrow(rows) == 0) return(NULL)
    k <- min(n, nrow(rows))
    rows[seq_len(k), ]
  }))

  if (is.null(sampled) || nrow(sampled) == 0) return(data.frame())

  biomeHue(sampled$Name, use_ncbi = FALSE, return_lineage = TRUE)
}


#' Clear the BiomeHue session cache
#'
#' Clears cached NCBI API results from the current R session.
#'
#' @return Invisibly returns the number of cached entries cleared.
#'
#' @examples
#' clear_biomeHue_cache()
#'
#' @export
clear_biomeHue_cache <- function() {
  .init_cache()
  cache <- get("lineages", envir = .biomeHue_cache)
  n <- length(cache)
  assign("lineages", list(), envir = .biomeHue_cache)
  if (n > 0) message(sprintf("Cleared %d cached entries", n))
  invisible(n)
}
