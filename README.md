# BiomeHue

Automatic, phylogenetically-informed colour palettes for microbiome barplots. Taxa from the same phylum are assigned colours in the same hue range (e.g. warm oranges for Bacteroidota, greens for Bacillota, purples for Actinomycetota), with variation in luminance and chroma so that related species are visually grouped but still distinguishable.

BiomeHue uses the **HCL colour space** for perceptual uniformity and ships with an internal **NCBI-derived lineage database** (~83K entries covering bacteria, archaea, and fungi) so that most taxa are resolved instantly without any API calls. Unknown taxa are optionally looked up via the NCBI Entrez API and cached for the session.

## Installation

```r
# install.packages("devtools")
devtools::install_github("feargalr/biomehue")
```

## Quick start

```r
library(BiomeHue)

# Get named colour vector for a set of taxa
colours <- biomeHue(c("Bacteroides", "Faecalibacterium", "Bifidobacterium",
                       "Akkermansia", "Escherichia_coli"))
colours
#>       Bacteroides  Faecalibacterium   Bifidobacterium       Akkermansia
#>         "#C68D44"          "#ABB682"          "#A393D1"         "#F8A2AA"
#>  Escherichia_coli
#>         "#BDC069"
```

Colours are deterministic: the same taxon always gets the same colour, regardless of what other taxa are in the input.

## Usage with ggplot2

```r
library(ggplot2)
library(BiomeHue)

# Your data in long format with columns: Sample, Taxon, Abundance
colours <- biomeHue(unique(my_data$Taxon))

ggplot(my_data, aes(x = Sample, y = Abundance, fill = Taxon)) +
  geom_bar(stat = "identity") +
  scale_fill_manual(values = colours) +
  theme_classic()
```

## Grouped legends by phylum

With the [`legendry`](https://cran.r-project.org/package=legendry) package you can add **phylum subtitles** to the legend, so that species are visually grouped under their phylum header. Here is a fully working example using the test data included with BiomeHue:

```r
library(BiomeHue)
library(ggplot2)
library(legendry)

# Load the included test data (wide format: samples × taxa)
data(BiomeHue_test.df)

# Reshape to long format
taxa <- colnames(BiomeHue_test.df)[-1]  # drop "Sample" column
demo_long <- reshape(
  BiomeHue_test.df,
  direction  = "long",
  varying    = taxa,
  v.names    = "Abundance",
  timevar    = "Taxon",
  times      = taxa,
  idvar      = "Sample"
)
demo_long$Taxon <- factor(demo_long$Taxon, levels = rev(taxa))

# Get colours and lineage info
lineage <- biomeHue(taxa, use_ncbi = FALSE, return_lineage = TRUE)
colours <- setNames(lineage$Colour, lineage$Taxon)

# Build the grouped legend key — maps each taxon to its phylum
group_key <- key_group_lut(members = lineage$Taxon, group = lineage$Phylum)

# Plot
ggplot(demo_long, aes(x = Sample, y = Abundance, fill = Taxon)) +
  geom_bar(stat = "identity", width = 0.85) +
  scale_fill_manual(values = colours) +
  labs(y = "Relative Abundance (%)", fill = NULL) +
  guides(fill = guide_legend_group(key = group_key, ncol = 1)) +
  theme_classic() +
  theme(
    legend.text = element_text(face = "italic", size = 8),
    legend.key.size = unit(0.4, "cm"),
    legendry.legend.subtitle = element_text(
      face = "bold", size = rel(0.9),
      margin = margin(t = 4, b = 2)
    )
  )
```

This produces a stacked barplot with the legend organised by phylum — bold headers like **Bacteroidota**, **Bacillota**, **Actinomycetota** etc., with the member taxa listed beneath each.

A more detailed example with simulated data is included at `inst/examples/demo_barplot.R`.

## Functions

### `biomeHue(taxa, use_ncbi = TRUE, return_lineage = FALSE)`

Main function. Takes a character vector of taxon names and returns a named vector of hex colours.

- **`taxa`** — character vector of taxon names at any level (species, genus, family, etc.). Supports underscores (`Bacteroides_fragilis`), spaces, and QIIME-style prefixes (`g__Bacteroides`).
- **`use_ncbi`** — if `TRUE` (default), unknown taxa are looked up via the NCBI Entrez API. Set to `FALSE` for offline use.
- **`return_lineage`** — if `TRUE`, returns a data frame with columns `Taxon`, `Colour`, `Phylum`, `Rank`, `Superkingdom` instead of a named vector.

```r
# Named vector (default)
biomeHue(c("Bacteroides", "Prevotella"), use_ncbi = FALSE)

# Data frame with lineage
biomeHue(c("Bacteroides", "Prevotella"), use_ncbi = FALSE, return_lineage = TRUE)
#>        Taxon  Colour       Phylum  Rank Superkingdom
#> 1 Bacteroides #C68D44 Bacteroidota genus     Bacteria
#> 2  Prevotella #9A4B29 Bacteroidota genus     Bacteria
```

### `biomeHue_palette(phylum = NULL, n = 5)`

Preview the colour scheme for genera in the internal database.

```r
# Sample from all phyla
biomeHue_palette(n = 3)

# Filter to specific phyla
biomeHue_palette(phylum = c("Bacillota", "Bacteroidota"))
```

### `clear_biomeHue_cache()`

Clears NCBI API results cached during the current R session.

## How it works

1. **Lineage resolution** — For each taxon, BiomeHue checks the internal NCBI-derived database (~83K entries at genus-level and above). If the taxon is a species binomial, the genus is extracted and looked up. If still not found and `use_ncbi = TRUE`, the NCBI Entrez API is queried as a fallback.

2. **Phylum hue mapping** — Each phylum is assigned a base hue angle on the colour wheel:

   | Phylum | Hue | Colour family |
   |--------|-----|---------------|
   | Bacteroidota | 30° | Warm oranges/reds |
   | Pseudomonadota | 80° | Yellow-greens |
   | Bacillota | 120° | Greens |
   | Actinomycetota | 300° | Purples |
   | Verrucomicrobiota | 0° | Reds/pinks |
   | Fusobacteriota | 210° | Blues |
   | Ascomycota | 320° | Magenta-purples |
   | Basidiomycota | 350° | Pink-reds |

   Unknown phyla are auto-assigned a hue from their name. Unclassified/Other taxa get grey.

3. **Within-phylum variation** — A deterministic hash of the taxon name varies the hue (±25°), luminance (40–80), and chroma (35–85) so that taxa from the same phylum are visually related but individually distinguishable.

## Supported input formats

BiomeHue handles common naming conventions out of the box:

```r
# Standard binomials
biomeHue("Bacteroides fragilis")

# Underscore-separated (MetaPhlAn, Kraken)
biomeHue("Bacteroides_fragilis")

# QIIME-style prefixes
biomeHue(c("g__Bacteroides", "s__Escherichia_coli"))

# Higher-level taxa
biomeHue(c("Bacteroidaceae", "Ruminococcaceae", "Enterobacteriaceae"))

# Special categories
biomeHue(c("Other", "Unclassified"))  # assigned grey
```

## Internal database

The package ships with a pre-processed NCBI taxonomy database containing ~83K entries (genus-level and above) covering:

- **Bacteria** (~62K entries)
- **Fungi** (~19K entries)
- **Archaea** (~1.5K entries)

The database is stored as a compressed `.rda` file (~500 KB) and is loaded lazily on first use. It can be rebuilt from the NCBI taxdump using the maintainer script in `data-raw/build_lineage_db.R`.

## Dependencies

- **Base R only** — no external package dependencies. Uses `grDevices::hcl()` for colour generation and base R `url()` for NCBI API calls.
- **Suggests:** `ggplot2` (for plotting), `legendry` (for grouped legends), `testthat` (for testing).
