# BiomeHue
Logical colour schema for bacterial microbiota (16S and metagenomic) barplots. Uses similar colours for phylogenetically similar taxa. I primarily built this for my own use to make it simpler to reuse the same colour palette across multiple datasets, however it may prove useful to others. Currently several species within the same taxa may have the same colour assigned.  

# Installation


```{r example}
library(devtools)
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
library(ggplot2)
library(reshape)

library(BiomeHue)

## Melt data into long format 
counts.df = melt(BiomeHue_test.df) #BiomeHue test data included with R library
counts.df$Taxa = counts.df$variable

## Extract data frame with colours
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
![BiomeHue](https://user-images.githubusercontent.com/7561275/225542713-dea0579c-2cf3-49c7-a269-b89a1c24e77a.png)
