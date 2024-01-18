# ENMs in R hands-on practical session: Tutorial 2
#### by Yucheol Shin (Department of Biological Sciences, Kangwon National University, Republic of Korea)
Feb dd 2024
@ Laboratory of Animal Behaviour and Conservation, Nanjing Forestry University

## Part 0. Setting up the working directory
Before diving in, we need to setup an environment to run the codes.

1) First, make sure to have both R and RStudio installed in your laptop.
2) Open RStudio and navigate to "File > New Project"
3) Select "New Directory > New Project"
4) Set the project name to "NJFU_ENMs_Workshop_2024"
5) Now you will be working within this directory for this workshop. 


## Part 1. Load packages and prepare environmental data
The terra and raster packages are for raster data handling in R, dplyr is for data frame manipulation and filtering, SDMtune is used for core model fitting and predictions, 
ENMeval is used to generate cross-validation folds, and rasterVis and ggplot2 packages are used for plotting model outputs in R.

```r
## load packages
library(terra)
library(raster)
library(dplyr)
library(SDMtune)
library(ENMeval)
library(rasterVis)
library(ggplot2)
```

Now, we are ready to load and prepare the environmrntal predictors. But before we do that, lets create the files to put the environmental data.
We can do that by simply running dir.create(), like so: 

```r
dir.create('climate')
dir.create('topo')
dir.create('land')
```

In the "climate" directory we will put climate rasters, in the "topo" directory we will put topographical variables (e.g. slope, elevation), and in the "land" directory we will put land cover/vegetation variables. 



To get our models, we first need to cut the global-scale layers into the modeling extent we need. So we will import a polygon file for the Korean Peninsula to process our environmental layers.
```r
poly <- sf::st_read('poly/kor_mer.shp')
```

Now we will import, crop, and mask our layers.
```r
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
```


We will then stack these layers into a single object. In the raster package you can achieve this with the "stack()" function, which will create an object of the class "RasterSatck". If you are using the terra package, use "c()" instead of "stack()"
```r
envs <- raster::stack(clim, topo, land)
```

It is always a good idea to print out your object on the console and actually plotting it out. By doing so you can check if all the necessary information for modeling is there (e.g. CRS).
```r
print(envs)
plot(envs[[1]])
```

Let's have a look at the console output for the RasterStack object "envs". We can see that it's a single object containing 22 raster layers. We can also see that its designated Coordinate Reference System (CRS) is WGS84 ("+datum=WGS84"), that each raster pixel has a spatial resolution of 0.008333333 dd (decimal degrees), and that it's got a spatial extent. These information are critical for spatial modeling. We also get the minimium and maximum cell values for each raster layer.
```r
> print(envs)
class      : RasterStack 
dimensions : 1188, 811, 963468, 22  (nrow, ncol, ncell, nlayers)
resolution : 0.008333333, 0.008333333  (x, y)
extent     : 124.1833, 130.9417, 33.10833, 43.00833  (xmin, xmax, ymin, ymax)
crs        : +proj=longlat +datum=WGS84 +no_defs 
names      :        bio1,       bio10,       bio11,       bio12,       bio13,       bio14,       bio15,       bio16,       bio17,       bio18,       bio19,        bio2,        bio3,        bio4,        bio5, ... 
min values :   -5.445834,    0.000000,  -21.283333,  560.000000,  131.000000,    2.000000,   25.804571,  323.000000,   11.000000,  139.000000,   11.000000,    1.000000,   16.278376,    0.000000,    0.500000, ... 
max values :   16.137501,   25.400000,    7.766667, 2209.000000,  402.000000,   81.000000,  111.652588, 1031.000000,  255.000000,  987.000000,  303.000000,   14.250000,  100.000000, 1356.491943,   31.299999, ...
```

Now plotting out the first layer within the "envs" RasterStack (which is the "bio1" layer), we get:
![envs](https://github.com/yucheols/ENMs_In_R/assets/85914125/21d01941-bf00-4bdc-9206-7189570bfa1e)

Looks pretty good!


Optional: you may want to export your processed rasters for later use and you can do this like so:
```r
### optional ::: you can choose to export the processed layers
for (i in 1:nlayers(envs)) {
  layer <- envs[[i]]
  file_name <- paste0('env_processed/', names(envs)[i], '.tif')
  writeRaster(layer, filename = file_name, overwrite = T)
}
```

Now we will remove highly corrleated variables from our RasterStack. This can be done in several different ways and in several different packages. For example, in SDMtune (the package we will be using for modeling), there are functions for variable selection. Here we will focus on the most basic method involving a Pearson's correlation test and excluding variables above a certain collinearity cutoff (usually |r| > 0.7). But I encourage you to explore other methods as well.   

```r
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
```
Printing out the "reduced" RasterStack, we can see that 15 highly correlated rasters have been removed from the initial set of 22 variables (nlayers = 7).

```r
> print(envs)
class      : RasterStack 
dimensions : 1188, 811, 963468, 7  (nrow, ncol, ncell, nlayers)
resolution : 0.008333333, 0.008333333  (x, y)
extent     : 124.1833, 130.9417, 33.10833, 43.00833  (xmin, xmax, ymin, ymax)
crs        : +proj=longlat +datum=WGS84 +no_defs 
names      :      bio15,      bio18,       bio2,       bio3,       elev,      slope, mixed_other 
min values :   25.80457,  139.00000,    1.00000,   16.27838,  -26.00000,    0.00000,     0.00000 
max values :  111.65259,  987.00000,   14.25000,  100.00000, 2503.50000,   37.96877,   100.00000 
```


## Part 2. Occurrence data collection
There are several ways to extract the occurrence data. But here we will use the megaSDM package to quickly scrape the data from GBIF. NOTE: you may need to install this package. Refer to the following link for instructions for installation: https://github.com/brshipley/megaSDM

```r
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
```

Now let's spatially thin the occurrence points. We can use the internal SDMtune function "thinData()", but this method matches the thinning distance to the pixel size of input raster layers. So, we may want to have more freedom with the selection of thinning distance. For that we can use the "humboldt.occ.rarefy()" function in the humboldt package. Also check out the "spThin" package.

Since our raw occurrence has > 600 occurrence points, lets try 10km thinning distance. This will thin down our data to 215 point. We will thin the data first using the humboldt function and then remove NAs (points falling on the pixels with no data values) using the thinData function of SDMtune.

```r
occs <- humboldt::humboldt.occ.rarefy(in.pts = occs, colxy = 2:3, rarefy.dist = 10, rarefy.units = 'km', run.silent.rar = F)
occs <- thinData(coords = occs[, c(2,3)], env = terra::rast(envs), x = 'long', y = 'lat', verbose = T)
```

As with the raster data, it is always a good idea to plot out the occurrence points on the map 
```r
plot(envs[[1]])
points(occs)
```

![points](https://github.com/yucheols/ENMs_In_R/assets/85914125/a9f48704-e2db-4aa3-8eed-3cf86935f018)



## Part 3. Background data sampling
```r
bg <- dismo::randomPoints(mask = envs[[1]], n = 10000, p = occs, excludep = T) %>% as.data.frame()
points(bg, col = 'blue')
```
![bg](https://github.com/yucheols/ENMs_In_R/assets/85914125/0354fa64-07f0-41a4-ba5a-cb8be130fd1a)


```r
head(bg)
colnames(bg) = colnames(occs)
```


## Part 4. Data partitioning for model evaluation
There are several ways to partition your data for model evaluation. But here we will first try k-fold random cross validation. You may select a specific partitioning method based on your research goals.

```r
cvfolds <- ENMeval::get.randomkfold(occs = occs, bg = bg, kfolds = 10)
```

## Part 5. Fitting candidate models and selecting the optimal model
```r
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
```

## Part 6. Response curves
With SDMtune you can get a response curve for each variable using the "plotResponse()" function. This will print out a ggplot-style output:
```r
plotResponse(model = opt.mod.obj, var = 'bio2', type = 'cloglog')
```
![bio2_resp](https://github.com/yucheols/ENMs_In_R/assets/85914125/82d490bf-5559-4660-925f-b25ea43cc8b6)





But you may wish to further customize the plot for better visualization or publication. For that we can actually extract the data used to build response curves and customize the plot using ggplot2.

To pull out the data though, we need to make a little work around because "plotResponse()" will automatically print out a finished plot. We can use this little wrapper function I've made (called "respDataPull()") to extract response data:

```r
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
```



Basically, what this function does, is that it loops over the number of input variables, extracts plot data, and merges them into a data frame for customization in ggplot2.

```r
# pull data
resp.data <- respDataPull(species_name = 'B.stejnegeri', model = opt.mod.obj, var = names(envs), 
                          type = 'cloglog', only_presence = F, marginal = F)
```



Now we can use this response data to customize our plot using the ggplot2 package

```r
resp.data %>%
  ggplot(aes(x = x, y = y)) +
  facet_wrap(~ var, scales = 'free') +
  geom_line(color = 'cornflowerblue', linewidth = 1.2) +
  geom_ribbon(aes(ymin = ymin, ymax = ymax), fill = 'grey', alpha = 0.4) +
  xlab('Variable') + ylab('Suitability') +
  theme_light()
```


Running the code above will produce a plot that looks loke this:

![response](https://github.com/yucheols/ENMs_In_R/assets/85914125/ee59712a-b27d-4a49-b811-dbb60da4b78a)


## Part 7. Model prediction
Now that we have our fitted MaxEnt model, we can now make landscape predictions!

```r
pred <- SDMtune::predict(object = opt.mod.obj, data = envs, type = 'cloglog', clamp = T, progress = T) %>% raster()
plot(pred)
```



![pred](https://github.com/yucheols/ENMs_In_R/assets/85914125/538a9b48-5a2b-4f6f-b820-30d1b39cae15)

Let's look at this model closely and take a note here. I've mentioned in Tutorial 1 that B.stejnegeri is found across northeastern China and the Korean Peninsula. But in our output model, we see that the predicted habitat suitability is almost zero for D.P.R Korea. Since we have very little knowledge of herpetofauna for that country, one might argue this is how it should be: that the habitat suitability of B.stejnegeri in D.P.R. Korea is very low. However, this is hihgly unlikely based on multiple lines of evidence. Therefore we may suspect that the prediction is in fact biased by a strong spatial sampling bias of occurrence points toward R.Korea. In turn, this means that our landscape predition is a representation of spatial sampling intensity instead of habitat suitability. This outcome is NOT the one we want. In the next tutorial, we will explore a way to compensate for such sampling bias. But here, we will just use this model to get a general idea of how the ENM workflow is organized.

Anyway, we can customize this prediction output further using ggplot2 and extensions provided by the rasterVis package.

```r
gplot(pred) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = rev(terrain.colors(1000)),
                       na.value = NA,
                       name = 'Suitability') +
  xlab('Long') + ylab('Lat') +
  theme_dark()
```

This will produce a figure that looks like this:

![pred_gg](https://github.com/yucheols/ENMs_In_R/assets/85914125/7a1642a0-eff0-4235-afbb-ff79ac1b75b1)


You can apply a different color palette. For example:
```r
gplot(pred) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = c('#2b83ba', '#abdda4', '#ffffbf', '#fdae61', '#4f05d7'),
                       na.value = NA,
                       name = 'Suitability') +
  xlab('Long') + ylab('Lat') +
  theme_dark()
```

![pred_gg2](https://github.com/yucheols/ENMs_In_R/assets/85914125/9bea1af9-c121-45ab-8f1c-3614031f44b4)


## n. Model extrapolation



