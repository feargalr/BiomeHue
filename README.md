# BiomeHue
Logical colour schema for microbiome barplots. 
Note this is currently under construction, with much more functionality to be added. However it may prove useful. The basic concept is that phylogenetically similar taxa should be coloured similarly. 

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
