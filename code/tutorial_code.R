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

## Other than the packages above, make sure to have "humboldt" package installed 

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

### stack into one object == use "c()" for the terra equivalent of the "raster::stack()", which is for the raster package
envs <- c(clim, topo, land)
print(envs)
plot(envs[[1]])

### optional ::: you can choose to export the processed layers



#####  PART 2 ::: occurrence data  #####
# there are several ways to extract the occurrence data. But here we will use the megaSDM package to quickly scrape the 
# data from GBIF. NOTE: you may need to install this package. Refer to the following link for instructions for installation:
# https://github.com/brshipley/megaSDM

# collect occurrence points
megaSDM::OccurrenceCollection(spplist = c('Bufo stejnegeri'), output = 'occs',
                              trainingarea = c(124.1833, 130.9417, 33.10833, 43.00833))

# now lets look at the data
occs <- read.csv('occs/Bufo_stejnegeri.csv')
head(occs)

# since we only need the species name, longitude, and latitude, we will pull out those three columns only
occs <- occs[, c('species', 'decimalLongitude', 'decimalLatitude')]
colnames(occs) = c('species', 'long', 'lat')

# spatially thin the occurrence points. We can use the internal SDMtune function "thinData()", but this method matches the thinning
# distance for
occs <- thinData(coords = occs[, c(2,3)], env = envs, x = 'long', y = 'lat', verbose = T, progress = T)

# plot out 

#####  PART 3 ::: background point sampling  #####
# you can sample your backgrounds in several different ways. We will first use random sampling 
# and will separately address spatial sampling bias correction. We will then compare the predictive outcomes of both models 

# sample random background ::: use the dismo package. Make sure to install this package as well if not installed already
bg <- dismo::randomPoints(mask = raster::raster(envs[[1]]), n = 10000,)





### lets remove highly correlated layers. This can be done in several different ways in several different packages. 
#    You may choose to use the internal SDMtune function. But this requires you to first fit a default niche model.
#    You may or may not want to do this. Otherwise you can do something like this:
