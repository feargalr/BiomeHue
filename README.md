# BiomeHue
Logical colour schema for bacterial microbiota barplots. Uses similar colours for phylogenetically similar taxa. This was developed for the human and murine gut microbiota. Other taxa may not be well covered. 

### Note 
BiomeHue is currently under development with more functionality to be added in the future. However it may prove useful even in it's current unfinished form. Currently several species within the same taxa may have the same colour assigned.  

# Installation


```{r example}
library(devtools
install_github("feargalr/biomehue")
library(BiomeHue)
```


# Usage
BiomeHue contains two simple functions
First to return all colours in the primary BiomeHue 



```{r example}
biomeHue_palette()
```

Second to provide a list of taxa

```{r example}
my_colors = biomeHue(taxa=c("Bifidobacterium","Akkermansia","Veillonella_atypica","Muribaculaceae"))

# Example usage with ggplot2
ggplot(data.df, aes(x = Sample, y = value, fill = Taxa)) + geom_bar(stat = "identity")+
  scale_fill_manual(values=my_colors)+theme_classic()
```

Example below plots with ggplot2 using test data. 

```{r example}
library(devtools
install_github("feargalr/biomehue")

library(ggplot2)
library(BiomeHue)
library(reshape)

#Melt data into long format 
counts.df = melt(BiomeHue_test.df) #BiomeHue test data included with R library
counts.df$Taxa = counts.df$variable

#Extract data frame with colours
biomeHue.df = biomeHue(taxa = counts.df$Taxa)

## Reorders taxa to group by ordered alphabetically, first by phylum and second by taxon. 
biomeHue.df = biomeHue.df[order(biomeHue.df$Phylum),]
counts.df$Taxa = factor(counts.df$Taxa,levels=biomeHue.df$Taxon) 

## plot with ggplot2
ggplot(counts.df, aes(x = Sample, y = value, fill = Taxa)) + geom_bar(width=0.7,stat = "identity")+
  ylab("Relative Abundance (%)")+
  theme_classic()+
  theme(legend.text = element_text(face = "italic"))+
  scale_fill_manual(values=biomeHue.df$Colour,name="Taxa",breaks=biomeHue.df$Taxon,
                    labels = gsub("_"," ",biomeHue.df$Taxon))
```
