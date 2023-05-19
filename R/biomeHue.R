#' Get a vector of colours for a microbiota barplot
#'
#' This function returns a vector of colours in hexadecimal format for a microbiota barplot. The colours are based on a pre-defined colour palette stored in the 'hue' data frame.
#'
#' @param taxa A character vector of bacterial names for which colours are desired.
#'
#' @return A character vector of colours in hexadecimal format.
#'
#' @examples
#' # Get the colours for the bacteria 'Bacteroides' and 'Faecalibacterium'
#' biomeHue(c('Bacteroides', 'Faecalibacterium'))
#'
#' # Get the full colour palette
#' biomeHue_palette()
#'
#' @export
biomeHue <- function(taxa) {

  # Return the rows of the 'hue' data frame where the 'Taxon' column matches the input 'taxa'
  return(hue[hue$Taxon %in% taxa, 'Colour'])
}

#' Get the full colour palette for microbiota barplots
#'
#' This function returns the full pre-defined colour palette for microbiota barplots. The colour palette is stored in the 'hue' data frame.
#'
#' @return A data frame with two columns: 'Taxon' (the bacterial name) and 'Colour' (the colour in hexadecimal format).
#'
#' @examples
#' # Get the full colour palette
#' biomeHue_palette()
#'
#' @export
biomeHue_palette <- function() {
  # Load the 'hue' data frame, which contains the pre-defined colour palette
  return(hue)
}





