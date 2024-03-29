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
library(rasterVis)
library(ggplot2)
library(sf)
library(pals)

## Other than the packages above, make sure to have "humboldt", "sf", "caret", and "pals" packages installed .

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

# It is always a good idea to print out your object on the console and actually plotting it out.
# By doing so you can check if all the necessary information for modeling is there (e.g. CRS)
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

# since our raw occurrence has > 600 occurrence points, lets try 10km thinning distance. This will thin down our data
# to 215 point. We will thin the data first using the humboldt function and then remove NAs using the thinData function.
occs <- humboldt::humboldt.occ.rarefy(in.pts = occs, colxy = 2:3, rarefy.dist = 10, rarefy.units = 'km', run.silent.rar = F)
occs <- thinData(coords = occs[, c(2,3)], env = terra::rast(envs), x = 'long', y = 'lat', verbose = T)

# as with the raster data, it is always a good idea to plot out the occurrence points on the map 
plot(envs[[1]])
points(occs)


#####  PART 3 ::: background point sampling  #####
# you can sample your backgrounds in several different ways. We will first use random sampling 
# and will separately address spatial sampling bias correction. We will then compare the predictive outcomes of both models 

# sample random background ::: use the dismo package. Make sure to install this package as well if not installed already
# we will sample the random points and then plot it out on the map
bg <- dismo::randomPoints(mask = envs[[1]], n = 10000, p = occs, excludep = T) %>% as.data.frame()
points(bg, col = 'blue')

head(bg)
colnames(bg) = colnames(occs)

#####  PART 4::: Data partitioning  #####
# there are several ways to partition your data for model evaluation. But here we will first try 
# k-fold random cross validation. You may select a specific partitioning method based on your research goals.
cvfolds <- ENMeval::get.randomkfold(occs = occs, bg = bg, kfolds = 10)

# let's visualize our CV folds for occurrence and background points
ENMeval::evalplot.grps(envs = envs, pts = occs, pts.grp = cvfolds$occs.grp)
ENMeval::evalplot.grps(envs = envs, pts = bg, pts.grp = cvfolds$bg.grp)


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
# We can print out the response curve for each variable using the "plotResponse" function. This prints out a ggplot style output.
plotResponse(model = opt.mod.obj, var = 'bio2', type = 'cloglog')

# However, for further plot customization in ggplot2, we must first pull out the data used to draw response curves. We can use a simple
# looping function below. This loop wraps around the plotResponse function.

# first, run the code below to save this fuction to your current R environment
respDataPull <- function(model, var, type, species_name, only_presence, marginal) {
  
  plotdata.list <- list()
  
  for (i in 1:length(var)) {
    plotdata <- plotResponse(model = model, var = var[[i]], type = type, only_presence = only_presence, marginal = marginal)
    plotdata <- ggplot2::ggplot_build(plotdata)$data
    plotdata <- plotdata[[1]]
    
    plotdata <- plotdata[, c(1:4)]
    plotdata$species <- species_name
    plotdata$var <- var[[i]]
    
    plotdata.list[[i]] <- plotdata
  }
  plotdata.df <- dplyr::bind_rows(plotdata.list)
  return(plotdata.df)
}

# Now we will run this function. We will save the output of this function into an object we can use.
resp.data <- respDataPull(species_name = 'B.stejnegeri', model = opt.mod.obj, var = names(envs), 
                          type = 'cloglog', only_presence = F, marginal = F)


# lets make a neat plot in ggplot style. We will use "facet_wrap" to show response curves for all variables in one plotting pane.
resp.data %>%
  ggplot(aes(x = x, y = y)) +
  facet_wrap(~ var, scales = 'free') +
  geom_line(color = 'cornflowerblue', linewidth = 1.2) +
  geom_ribbon(aes(ymin = ymin, ymax = ymax), fill = 'grey', alpha = 0.4) +
  xlab('Variable') + ylab('Suitability') +
  theme_light()


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
  xlab('Long') + ylab('Lat') +
  theme_dark()

# You can apply a different color palettte, for example:
gplot(pred) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = c('#2b83ba', '#abdda4', '#ffffbf', '#fdae61', '#4f05d7'),
                       na.value = NA,
                       name = 'Suitability') +
  xlab('Long') + ylab('Lat') +
  theme_dark()

# If you want to make the figures using dedicated GIS softwares instead of doing it in R, you can do so by exporting the output
# prediction as a raster.
writeRaster(pred, 'output_rast/pred.tif', overwrite = T)


#####  PART 8 ::: Model extrapolation  #####
# we will spatially project our fitted model to Japan
# lets import the projection layers. You can prepare the projection layers following the same steps we went through 
# for our initial layer prep.

# Here, I will just import the projection layers I already prepared to save time
proj.envs <- raster::stack(list.files(path = 'proj_envs', pattern = '.tif$', full.names = T))
names(proj.envs) = c('bio15', 'bio18', 'bio2', 'bio3', 'elev', 'mixed_other', 'slope')

plot(proj.envs[[1]])

# For projection we just use the "SDMtune::predict()" function like we did the first time. But here we will provide
# our projection layers for the "data" argument
spat.proj <- SDMtune::predict(object = opt.mod.obj, data = terra::rast(proj.envs), 
                              type = 'cloglog', clamp = T, progress = T) %>% raster()

# Lets plot out the model
plot(spat.proj)

# ggplot style
gplot(spat.proj) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = rev(terrain.colors(1000)),
                       na.value = NA,
                       name = 'Suitability') +
  xlab('Long') + ylab('Lat') +
  theme_dark()


# Since we are predicting the model to a different area than used to train our model, there might be some extrapolation happening
# with our prediction. When extrapolation happens, this essentially means that the model is predicting to the values outside the range
# of values of the original data. Habitat suitability predicted in areas with high extrapolation should be interpreted with caution.

# But how do we assess extrapolation risk? one way to do it is by calculating MESS (Multivariate Environmental Similarity Surface). 
# This can be done using the dismo package

# Let's prepare data for MESS. We first need our projection layers
print(proj.envs)

# We also need "reference values" extracted from the layers used for original model calibration
print(envs)

ref.val <- raster::extract(envs, occs) %>% as.data.frame()
head(ref.val)

# Let's run MESS
mess <- dismo::mess(x = proj.envs, v = ref.val, full = F)
plot(mess$mess)

# Let's plot the MESS raster. You need the pals package loaded to be able to use the "ocean.thermal" palette.
gplot(mess$mess) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = as.vector(ocean.thermal(22)),
                       na.value = 'transparent',
                       name = 'MESS',
                       breaks = c(-10, -260),
                       labels = c('Low', 'High')) +
  xlab('Long') + ylab('Lat')
  
