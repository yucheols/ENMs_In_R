#### ENMs in R tutorials ::: hands-on workshop @NJFU Lab of Animal Behaviour and Conservation ::: Feb 2024
#### In this workshop, you will learn how to implement all the necessary steps of niche modeling entirely in R

#### We will use the Korean water toad (Bufo stejnegeri) as an example. This is a forest-dwelling specialist adapted to mountain streams.

# NOTE: it is always a good idea to break down your workflow into "parts". I do this by adding 5 "#" signs at both sides of my comment.
# This will enable you to collapse your workflow into organize chunks.
# You will see this workflow is formatted into "##### PART 1 ::: blah blah #####", "##### PART 2 ::: blah blah #####" and so on.

#######################################################  The workflow starts here  ######################################################
## load packages
library(terra)
library(dplyr)
library(SDMtune)
library(ENMeval)
library(extrafont)
library(rasterVis)
library(ggplot2)

## run the codes below ONCE ONLY == after running them once, lock them with "#" so that they are recognized as comments, not codes 
#dir.create('climate')
#dir.create('topo')
#dir.create('land')
#dir.create('env_processed') # to contain the processed raster layers

#####  PART 1 ::: load and prepare environmental data  #####
### first, we will import a polygon file for the Korean Peninsula to process our environmental layers
poly <- vect('poly/kor_mer.shp')

### now we will import, crop, and mask our layers
# climate
clim <- rast(list.files(path = 'climate', pattern = '.tif$', full.names = T))  # import
clim <- crop(clim, poly)                            # crop == crop to geographic extent
clim <- mask(clim, poly)                            # mask == cut along the polygon boundary ("cookie cutter")

plot(clim[[1]]) # It is always a good idea to plot out the processed layer(s)

# topo
topo <- rast(list.files(path = 'topo', pattern = '.tif$', full.names = T))
topo <- crop(topo, poly)
topo <- mask(topo, poly)

# land cover
land <- rast('land/mixed_other.tif')
land <- crop(land, poly)
land <- mask(land, poly)

### stack into one object
envs <- rast(c(clim, topo, land))
print(envs)

### optional ::: you can choose to export the processed layers


#####  PART 2 ::: occurrence data  #####
# there are several ways to extract the occurrence data. But here we will use the megaSDM package to quickly scrape the 
# data from GBIF. NOTE: you may need to install this package. Refer to the following link for instructions for installation:
# https://github.com/brshipley/megaSDM

megaSDM::OccurrenceCollection(spplist = c('Bufo stejnegeri'), output = 'occs',
                              trainingarea = c(124.1833, 130.9417, 33.10833, 43.00833))
