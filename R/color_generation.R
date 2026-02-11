# --- Phylum hue definitions ---

#' @keywords internal
.define_phylum_hues <- function() {
  c(
    # Bacteria - major phyla
    "Bacillota"          = 120,  # Green-cyan (formerly Firmicutes)
    "Firmicutes"         = 120,  # Legacy name
    "Bacteroidota"       = 30,   # Orange-red
    "Bacteroidetes"      = 30,   # Legacy name
    "Actinomycetota"     = 300,  # Purple-magenta
    "Actinobacteriota"   = 300,  # Legacy name
    "Actinobacteria"     = 300,  # Legacy name
    "Pseudomonadota"     = 80,   # Yellow-green
    "Proteobacteria"     = 80,   # Legacy name
    "Verrucomicrobiota"  = 0,    # Red
    "Verrucomicrobia"    = 0,    # Legacy name
    "Fusobacteriota"     = 210,  # Blue
    "Fusobacteria"       = 210,  # Legacy name
    "Mycoplasmatota"     = 160,  # Teal
    "Tenericutes"        = 160,  # Legacy name
    "Desulfobacterota"   = 180,  # Cyan
    "Spirochaetota"      = 240,  # Deep blue
    "Spirochaetes"       = 240,  # Legacy name
    "Synergistota"       = 270,  # Blue-purple
    "Synergistetes"      = 270,  # Legacy name
    "Cyanobacteria"      = 170,  # Cyan-green
    "Campylobacterota"   = 50,   # Orange

    # Archaea
    "Euryarchaeota"      = 45,   # Orange-yellow
    "Thermoproteota"     = 200,  # Steel blue
    "Crenarchaeota"      = 200,  # Legacy name
    "Halobacteriota"     = 340,  # Magenta-red
    "Asgardarchaeota"    = 190,  # Cyan-blue
    "Methanobacteriota"  = 55,   # Yellow

    # Fungi
    "Ascomycota"         = 320,  # Magenta-purple
    "Basidiomycota"      = 350,  # Pink-red
    "Mucoromycota"       = 15,   # Red-orange
    "Chytridiomycota"    = 260   # Indigo
  )
}

# --- Deterministic hash ---

#' @keywords internal
.hash_taxon_name <- function(taxon, seed = 0L) {
  # Hash with good distribution, using doubles to avoid integer overflow
  chars <- utf8ToInt(taxon)
  h <- 5381 + seed * 16777259
  for (ch in chars) {
    h <- ((h * 33) + ch) %% 2147483647
  }
  # Normalize to 0-1
  (h %% 999983) / 999983
}

# --- Color generation ---

#' @keywords internal
.generate_hcl_color <- function(taxon, phylum) {
  # Unclassified / unknown -> grey
  if (is.na(phylum) || phylum == "Unclassified") {
    hash <- .hash_taxon_name(taxon)
    lum <- 45 + hash * 35
    return(grDevices::hcl(h = 0, c = 0, l = lum))
  }

  # Get base hue for phylum
  phylum_hues <- .define_phylum_hues()
  base_hue <- phylum_hues[phylum]

  if (is.na(base_hue)) {
    # Unknown phylum: auto-assign hue from phylum name hash
    base_hue <- .hash_taxon_name(phylum) * 360
  }

  # Three independent hashes for hue, luminance, chroma
  h1 <- .hash_taxon_name(taxon, seed = 0L)
  h2 <- .hash_taxon_name(taxon, seed = 7L)
  h3 <- .hash_taxon_name(taxon, seed = 13L)

  # Hue: base ± 25 degrees (50 degree spread within phylum)
  hue <- (base_hue + (h1 - 0.5) * 50) %% 360

  # Luminance: 40-80 range (wide spread for visual distinction)
  lum <- 40 + h2 * 40

  # Chroma: 35-85 range
  chroma <- 35 + h3 * 50

  grDevices::hcl(h = hue, c = chroma, l = lum)
}

#' @keywords internal
.generate_color_palette <- function(taxa, lineage_info) {
  colors <- vapply(taxa, function(taxon) {
    phylum <- lineage_info[[taxon]]$phylum
    .generate_hcl_color(taxon, phylum)
  }, character(1))
  names(colors) <- taxa
  colors
}
