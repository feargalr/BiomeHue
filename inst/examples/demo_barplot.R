## BiomeHue demo: compositional barplots from shotgun metagenomics
## Generates a dummy dataset and plots it with biomeHue-assigned colours
## Uses legendry::guide_legend_group() for phylum-grouped legends

library(BiomeHue)
library(ggplot2)
library(legendry)

# --- Create dummy compositional data ---
# 10 samples, 20 species across 5 phyla
set.seed(42)

taxa <- c(
  # Bacteroidota (warm oranges/reds)
  "Bacteroides_fragilis", "Bacteroides_vulgatus", "Prevotella_copri",
  "Alistipes_putredinis",
  # Bacillota (greens)
  "Faecalibacterium_prausnitzii", "Roseburia_intestinalis",
  "Ruminococcus_bromii", "Streptococcus_salivarius",
  "Enterococcus_faecalis", "Veillonella_parvula",
  # Actinomycetota (purples)
  "Bifidobacterium_longum", "Bifidobacterium_adolescentis",
  "Collinsella_aerofaciens",
  # Pseudomonadota (yellow-greens)
  "Escherichia_coli", "Klebsiella_pneumoniae",
  # Verrucomicrobiota (reds)
  "Akkermansia_muciniphila",
  # Fungi
  "Candida_albicans",
  # Archaea
  "Methanobrevibacter_smithii",
  # Catch-all
  "Other", "Unclassified"
)

n_samples <- 10
n_taxa <- length(taxa)

# Generate random compositional data (Dirichlet-ish via gamma)
alpha <- c(
  15, 10, 8, 5,           # Bacteroidota
  12, 6, 4, 3, 2, 3,      # Bacillota
  8, 4, 3,                 # Actinomycetota
  5, 2,                    # Pseudomonadota
  6,                       # Verrucomicrobiota
  1,                       # Fungi
  2,                       # Archaea
  3, 2                     # Other/Unclassified
)

abundance_matrix <- matrix(NA, nrow = n_samples, ncol = n_taxa)
for (i in seq_len(n_samples)) {
  raw <- rgamma(n_taxa, shape = alpha)
  abundance_matrix[i, ] <- raw / sum(raw) * 100
}

# Build data frame
demo_data <- data.frame(
  Sample = paste0("Sample_", sprintf("%02d", 1:n_samples)),
  abundance_matrix,
  check.names = FALSE
)
colnames(demo_data)[-1] <- taxa

# --- Reshape to long format ---
demo_long <- reshape(
  demo_data,
  direction = "long",
  varying = taxa,
  v.names = "Abundance",
  timevar = "Taxon",
  times = taxa,
  idvar = "Sample"
)
demo_long$Taxon <- factor(demo_long$Taxon, levels = rev(taxa))
rownames(demo_long) <- NULL

# --- Get BiomeHue colours + lineage ---
lineage_info <- biomeHue(taxa, use_ncbi = FALSE, return_lineage = TRUE)
colours <- setNames(lineage_info$Colour, lineage_info$Taxon)

cat("\nTaxon -> Phylum -> Colour mapping:\n")
print(lineage_info[, c("Taxon", "Phylum", "Colour")])

# --- Build grouped legend key ---
# key_group_lut maps each taxon to its phylum for legend subtitles
group_key <- key_group_lut(
  members = lineage_info$Taxon,
  group   = lineage_info$Phylum
)

# --- Plot ---
p <- ggplot(demo_long, aes(x = Sample, y = Abundance, fill = Taxon)) +
  geom_bar(stat = "identity", width = 0.85) +
  scale_fill_manual(values = colours) +
  labs(
    title = "Microbiome Composition (BiomeHue colours)",
    x = NULL,
    y = "Relative Abundance (%)",
    fill = NULL
  ) +
  theme_classic(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.text = element_text(size = 8),
    legend.key.size = unit(0.4, "cm"),
    legendry.legend.subtitle = element_text(
      face = "bold", size = rel(0.9),
      margin = margin(t = 4, b = 2)
    )
  ) +
  guides(fill = guide_legend_group(key = group_key, ncol = 1))

print(p)

# Save
ggsave("biomeHue_demo_barplot.pdf", p, width = 12, height = 7)
cat("\nSaved to biomeHue_demo_barplot.pdf\n")
