#### ENMs in R tutorials ::: hands-on workshop @NJFU Lab of Animal Behaviour and Conservation ::: Feb 2024
#### In this workshop, you will learn how to implement all the necessary steps of niche modeling entirely in R

#### We will use the Korean water toad (Bufo stejnegeri) as an example. This is a forest-dwelling specialist adapted to mountain streams.

# NOTE: it is always a good idea to break down your workflow into "parts". I do this by adding 5 "#" signs at both sides of my comment.
# This will enable you to collapse your workflow into organize chunks.
# You will see this workflow is formatted into "##### PART 1 ::: blah blah #####", "##### PART 2 ::: blah blah #####" and so on.

#######################################################  The workflow starts here  ######################################################
## load packages
library(terra)
library(raster)
library(dplyr)
library(SDMtune)
library(ENMeval)
library(extrafont)
library(rasterVis)
library(ggplot2)

## Other than the packages above, make sure to have "humboldt", "sf", "caret" packages installed .

## Note on the usage of the "raster" package ::: Since SDMtune accepts SpatRaster objects created from the terra package, 
## we really don't need to rely on the raster package. But the exclusive use of terra package is producing some weird errors 
## on my computer that I cannot fully solve. So I'm mainly using the raster package here for raster data processing and will 
## use the terra package for formatting data into SDMtune inputs. 


## run the codes below ONCE ONLY == after running them once, lock them with "#" so that they are recognized as comments, not codes 
#dir.create('climate')
#dir.create('topo')
#dir.create('land')
#dir.create('env_processed') # to contain the processed raster layers

#####  PART 1 ::: load and prepare environmental data  #####
### first, we will import a polygon file for the Korean Peninsula to process our environmental layers
poly <- sf::st_read('poly/kor_mer.shp')

### now we will import, crop, and mask our layers
# climate
clim <- raster::stack(list.files(path = 'climate', pattern = '.tif$', full.names = T))  # import
clim <- raster::crop(clim, extent(poly))                            # crop == crop to geographic extent
clim <- mask(clim, poly)                            # mask == cut along the polygon boundary ("cookie cutter")

plot(clim[[1]]) # It is always a good idea to plot out the processed layer(s)

# topo
topo <- raster::stack(list.files(path = 'topo', pattern = '.tif$', full.names = T))
topo <- crop(topo, extent(poly))
topo <- mask(topo, poly)

# land cover
land <- raster('land/mixed_other.tif')
land <- crop(land, extent(poly))
land <- mask(land, poly)

### stack into one object == use "c()" for the terra equivalent of the "raster::stack()", which is for the raster package
envs <- raster::stack(clim, topo, land)
print(envs)
plot(envs[[1]])

### optional ::: you can choose to export the processed layers
for (i in 1:nlayers(envs)) {
  layer <- envs[[i]]
  file_name <- paste0('env_processed/', names(envs)[i], '.tif')
  writeRaster(layer, filename = file_name, overwrite = T)
}

### lets remove highly correlated layers. This can be done in several different ways in several different packages. 
#    You may choose to use the internal SDMtune function. But this requires you to first fit a default niche model.
#    You may or may not want to do this. Otherwise you can do something like this:

# make correlation table first
envs_df <- envs %>% as.data.frame() %>% na.omit()
cor_mat <- cor(envs_df, method = 'pearson')
print(cor_mat)

# remove highly correlated using cutoff of |r| < 0.7
find_cor <- caret::findCorrelation(cor_mat, cutoff = abs(0.7)) 
print(find_cor)

# drop highly correlated layers
envs <- dropLayer(envs, sort(find_cor))
print(envs)


#####  PART 2 ::: occurrence data  #####
# there are several ways to extract the occurrence data. But here we will use the megaSDM package to quickly scrape the 
# data from GBIF. NOTE: you may need to install this package. Refer to the following link for instructions for installation:
# https://github.com/brshipley/megaSDM

# collect occurrence points
megaSDM::OccurrenceCollection(spplist = c('Bufo stejnegeri'), output = 'occs',
                              trainingarea = extent(envs[[1]]))

# now lets look at the data
occs <- read.csv('occs/Bufo_stejnegeri.csv')
head(occs)

# since we only need the species name, longitude, and latitude, we will pull out those three columns only
occs <- occs[, c('species', 'decimalLongitude', 'decimalLatitude')]
colnames(occs) = c('species', 'long', 'lat')
head(occs)

# spatially thin the occurrence points. We can use the internal SDMtune function "thinData()", but this method matches the thinning
# distance to the spatial resolution of input raster layers. So, we may want to have more freedom with the selection of thinning
# distance. For that we can use the "humboldt.occ.rarefy()" function in the humboldt package. Also check out the "spThin" package

# since out raw occurrence has > 600 occurrence points, lets try 10km thinning distance. This will thin down our data
# to 215 point
occs <- humboldt::humboldt.occ.rarefy(in.pts = occs, colxy = 2:3, rarefy.dist = 10, rarefy.units = 'km', run.silent.rar = F)

# as with the raster data, it is always a good idea to plot out the occurrence points on the map 
plot(envs[[1]])
points(occs[, c(2,3)])


#####  PART 3 ::: background point sampling  #####
# you can sample your backgrounds in several different ways. We will first use random sampling 
# and will separately address spatial sampling bias correction. We will then compare the predictive outcomes of both models 

# sample random background ::: use the dismo package. Make sure to install this package as well if not installed already
# we will sample the random points and then plot it out on the map
bg <- dismo::randomPoints(mask = envs[[1]], n = 10000, p = occs[, c(2,3)], excludep = T) %>% as.data.frame()
points(bg, col = 'blue')

head(bg)
colnames(bg) = colnames(occs[, c(2,3)])

#####  PART 4::: Data partitioning  #####
# there are several ways to partition your data for model evaluation. But here we will first try 
# k-fold random cross validation
cvfolds <- ENMeval::get.randomkfold(occs = occs[, c(2,3)], bg = bg, kfolds = 10)





