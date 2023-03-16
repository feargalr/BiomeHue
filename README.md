# BiomeHue
Logical colour schema for bacterial microbiota barplots. Uses similar colours for phylogenetically similar taxa. This was developed for the human and murine gut microbiota. Other taxa may not be well covered. 

### Note 
BiomeHue is currently under development with more functionality to be added in the future. However it may prove useful even in it's current unfinished form. Currently several species within the same taxa may have the same colour assigned.  

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
