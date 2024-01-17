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

### stack into one object == use "c()" for the terra equivalent of the "raster::stack()"
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
# to 215 point. We will thin the data first using the humboldt function and then remove NAs using the thinData function.
occs <- humboldt::humboldt.occ.rarefy(in.pts = occs, colxy = 2:3, rarefy.dist = 10, rarefy.units = 'km', run.silent.rar = F)
occs <- thinData(coords = occs[, c(2,3)], env = envs, x = 'long', y = 'lat', verbose = T)

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
# k-fold random cross validation. You may select a specific partitioning method based on your research goals.
cvfolds <- ENMeval::get.randomkfold(occs = occs, bg = bg, kfolds = 10)


#####  PART 5 ::: Model fitting  #####
# Now we have all the data prepared to fit our niche models! 
# since we are using SDMtune, we need to format our data into a suitable format (SWD) recognized by the package
# first we will convert our layers (which is currently a RasterStack object) into a terra SpatRaster class
head(occs)
head(bg)

envs <- rast(envs)
sp.data <- prepareSWD(species = 'Bufo stejnegeri', env = envs, p = occs, a = bg, verbose = T)

# now let's build a default MaxEnt model that can be carried downstream 
def.mod <- SDMtune::train(method = 'Maxent', data = sp.data, folds = cvfolds, progress = T, iter = 5000, type = 'cloglog')
print(def.mod)

# now lets fit several different candidate models. We will use the "gridSearch" function. This is similar to running
# the "ENMevaluate" function in the ENMeval package

# For this demo we will test a relatively small number of model paramaters as adding more parameters increases computing time.
# but you can choose add more combinations depending on your study design  

# we are testing 4 feature combinations and 3 regularization values = 4 X 3 = 12 models
find.mod <- gridSearch(model = def.mod, 
                       hypers = list(fc = c('lq', 'lqh', 'lqhp', 'lqhpt'),
                                     reg = seq(1, 2, by = 0.5)),
                       metric = 'auc',
                       save_models = T, 
                       interactive = F,
                       progress = T)

# The above code actually takes quite a bit to run...(~ 40 minutes)
# so for the purpose of this demo we will just load the previously saved model object by running the code below

# find.mod <- readr::read_rds('models/models.rds')

# Now select the optimal model. This can also be done in several different ways and by applying different criteria. 
# Here we will select the model with maximum test AUC
opt.mod <- find.mod@results %>% filter(test_AUC == max(test_AUC))
print(opt.mod)

# We can see that our optimal model is built with LQHP features and a regularization value of 1.0. This is the 3rd model out of 12 models.
# We can also see that our chosen evaluation metric (test AUC) is pretty high.

# let's save our optimal model into a separate object to make downstream model predictions easier 
opt.mod.obj <- find.mod@models[[3]]
print(opt.mod.obj)

# in addition to AUC, you may want to calculate TSS. You can do this like so:
tss(model = opt.mod.obj, test = T)

# lets look at variable importance 
var.imp <- maxentVarImp(opt.mod.obj)
print(var.imp)

#####  PART 6 ::: Response curves  #####


#####  PART 7 ::: model prediction  #####
# now that we have our fitted MaxEnt model, we can now make landscape predictions!
pred <- SDMtune::predict(object = opt.mod.obj, data = envs, type = 'cloglog', clamp = T, progress = T) %>% raster()
plot(pred)

# let's make a neat plot in the style of ggplot2. We will use the same default color scheme called the "terrain.colors". 
# But of course you can choose a different color palette. There's a broad selection of color palettes available in R.
gplot(pred) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = rev(terrain.colors(1000)),
                       na.value = NA,
                       name = 'Suitability') +
  xlab('Long') + ylab('Lat') 
