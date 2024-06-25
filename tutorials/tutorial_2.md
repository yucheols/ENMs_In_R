# ENMs in R hands-on practical session: Tutorial 2
#### by Yucheol Shin (PhD student, Richard Gilder Graduate School, American Museum of Natural History, USA)

- 1st installment: 28 Feb 2024 @ Laboratory of Animal Behaviour and Conservation, Nanjing Forestry University, China
- 2nd installment: 13 Jun 2024 @ Yanbian University, China
- 3rd installment: 1 July 2024 @ Laboratory of Herpetology, Kangwon National University, South Korea
  
## Part 0. Setting up the working directory
Before diving in, we need to setup an environment to run the codes.

1) First, make sure to have both R and RStudio installed in your laptop.
2) Open RStudio and navigate to "File > New Project"
3) Select "New Directory > New Project"
4) Set the project name to "ENMs_Workshop_2024"
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

names(topo) = c('elevation', 'slope')  # rename variable names to something shorter

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
names      :      bio15,      bio18,       bio2,       bio3,  elevation,      slope, mixed_other 
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

Since our raw occurrence has > 600 occurrence points, lets try 10km thinning distance. This will thin down our data to 220 points. Note that this number could vary depending on when exactly you download the dataset. We will thin the data first using the humboldt function and then remove NAs (points falling on the pixels with no data values) using the thinData function of SDMtune.

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


Let's take a note here. See how the occurrence points are clustered in R. Korea but pretty much absent in D.P.R. Korea? We will get back to this later in this tutorial and in the next one to illustrate an important consideration to make while running ENMs. 

## Part 3. Background data sampling
Now that we have the occurrence data prepared, we also need to have some background points to go with it. For this first tutorial, I will go ahead and sample 10,000 random background points. This is done pretty easily using the "randomPoints()" function of the dismo package. After that, let's plot our sampled background points across the modeling extent. We can see the points are pretty much distributed all over the Korean Peninsula.



```r
bg <- dismo::randomPoints(mask = envs[[1]], n = 10000, p = occs, excludep = T) %>% as.data.frame()
points(bg, col = 'blue')
```

![bg](https://github.com/yucheols/ENMs_In_R/assets/85914125/0354fa64-07f0-41a4-ba5a-cb8be130fd1a)


Let's match the column names of our background points to the column names of the occurrence dataset.

```r
head(bg)
colnames(bg) = colnames(occs)
```


## Part 4. Data partitioning for model evaluation
Now we need to partition our data into "training" and "testing" folds. There are several ways to partition your data for model evaluation. But here we will try k-fold random cross-validation. This approach randomly divides your data into k-equal parts, using k-1 part of data for building the models and then using the remaining one part for model evaluation. You may select a specific partitioning method based on your research goals or you can even customize the selection of your folds using different packages. For more details on partitioning schemes, here is an excellent vignette by Dr. Jamie Kass: https://jamiemkass.github.io/ENMeval/articles/ENMeval-2.0-vignette.html#partition

```r
cvfolds <- ENMeval::get.randomkfold(occs = occs, bg = bg, kfolds = 10)
```

In our code, we used the ENMeval package get our data partitions, setting "kfolds = 10". This means that our data has been partitioned into 10 equal parts. 9 parts of the data will go into model fitting and the remaining one part will be used for model testing.

Now, let's look at the fold assignments for the occurrence data:

```r
ENMeval::evalplot.grps(envs = envs, pts = occs, pts.grp = cvfolds$occs.grp)
```
![occs_folds](https://github.com/yucheols/ENMs_In_R/assets/85914125/5535a034-a36e-4ea7-8d04-740cc0f257a7)


And now for the background data:
```r
ENMeval::evalplot.grps(envs = envs, pts = bg, pts.grp = cvfolds$bg.grp)
```
![bg_folds](https://github.com/yucheols/ENMs_In_R/assets/85914125/b2f15ab3-e68a-447e-bbef-3cb8eaaddf00)


## Part 5. Fitting candidate models and selecting the optimal model
Now we have all the data prepared to fit our niche models! Since we are using SDMtune, we need to format our data into a suitable format (SWD) recognized by the package. First we will convert our layers (which is currently a RasterStack object) into a terra SpatRaster class, and then use the "prepareSWD()" to format the data for modeling.

```r
sp.data <- prepareSWD(species = 'Bufo stejnegeri', env = terra::rast(envs), p = occs, a = bg, verbose = T)
```

Now let's build a default MaxEnt model that can be carried downstream 
```r
def.mod <- SDMtune::train(method = 'Maxent', data = sp.data, folds = cvfolds, progress = T, iter = 5000, type = 'cloglog')
print(def.mod)
```

Now lets fit several different candidate models. We will use the "gridSearch" function. This is similar to running the "ENMevaluate" function in the ENMeval package. For this demo we will test a relatively small number of model paramaters as adding more parameters increases computing time, but you can choose add more combinations depending on your study design. We are testing 4 feature combinations and 3 regularization values, So 4 X 3 = 12 models

```r
find.mod <- gridSearch(model = def.mod, 
                       hypers = list(fc = c('lq', 'lqh', 'lqhp', 'lqhpt'),
                                     reg = seq(1, 2, by = 0.5)),
                       metric = 'auc',
                       save_models = T, 
                       interactive = F,
                       progress = T)
```


The above code actually takes quite a bit to run...(~ 40 minutes), so for the purpose of this demo we will just load the previously saved model object by running the code below.

```r
find.mod <- readr::read_rds('models/models.rds')
```

Now select the optimal model. This can also be done in several different ways and by applying different criteria. Here we will select the model with maximum test AUC (AUC calculated from the testing data). 
```r
opt.mod <- find.mod@results %>% filter(test_AUC == max(test_AUC))
print(opt.mod)
```

We can see that our optimal model is built with LQHP features and a regularization value of 1.0. This is the 3rd model out of 12 models. We can also see that our chosen evaluation metric (test AUC) is pretty high. Let's save our optimal model into a separate object to make downstream model predictions easier 

```r
opt.mod.obj <- find.mod@models[[3]]
print(opt.mod.obj)
```

In addition to AUC, you may want to calculate TSS. You can do this like so:
```r
tss(model = opt.mod.obj, test = T)
```

#### Lets look at variable importance
```r 
var.imp <- maxentVarImp(opt.mod.obj)
```

Printing this object in the console returns the variable importance based on permutation importance and percent contribution.

```r 
print(var.imp)
     Variable Percent_contribution Permutation_importance
1        bio2             26.93911               11.43156
2       bio15             18.67193               37.38540
3 mixed_other             18.23126                4.96671
4       bio18             14.25700               20.52207
5   elevation              9.80706                6.67403
6        bio3              6.37591               15.40458
7       slope              5.71771                3.61569
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

![response](https://github.com/yucheols/ENMs_In_R/assets/85914125/a6b41399-a5b3-4ab8-b14e-bb46a439a10f)



## Part 7. Model prediction
Now that we have our fitted MaxEnt model, we can now make landscape predictions! We will use the internal SDMtune function ("predict()") to get our model prediction raster. Be sure to not use the base R function of the same name (this will throw out an error). You can specify that you're using the SDMtune function by writing "SDMtune::predict()" 

```r
pred <- SDMtune::predict(object = opt.mod.obj, data = envs, type = 'cloglog', clamp = T, progress = T) %>% raster()
plot(pred)
```



![pred](https://github.com/yucheols/ENMs_In_R/assets/85914125/c1a8b14d-de54-42bd-b4bd-3ff7eb71333f)


Let's look at this model closely and take a note here. I've mentioned in Tutorial 1 that B. stejnegeri is found across northeastern China and the Korean Peninsula. But in our output model, we see that the predicted habitat suitability is almost zero across much of D.P.R Korea. Since we have very little knowledge of herpetofauna for that country, one might argue this is how it should be: that the habitat suitability of B. stejnegeri in D.P.R. Korea is very low. However, this is hihgly unlikely based on multiple lines of evidence (e.g. distribution of mountain ranges, habitat types, available literature, etc). Therefore we may suspect that the prediction is in fact biased by a strong spatial sampling bias of occurrence points toward R. Korea. In turn, this means that our landscape predition is a representation of spatial sampling intensity instead of habitat suitability. This outcome is NOT the one we want. In the next tutorial, we will explore a way to compensate for such sampling bias. But here, we will just use this model to get a general idea of how the ENM workflow is organized.

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

![pred_gg](https://github.com/yucheols/ENMs_In_R/assets/85914125/bde03dd6-8d7c-414a-8c73-ff559ca8b73e)



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

![pred_gg2](https://github.com/yucheols/ENMs_In_R/assets/85914125/457b1106-0f2d-4fcc-9873-db20aa46c242)




If you want to make the figures using dedicated GIS softwares instead of doing it in R, you can do so by exporting the output prediction as a raster.
```r
writeRaster(pred, 'output_rast/pred.tif')
```

## 8. Model extrapolation
We will spatially project our fitted model to Japan. Let's first import the projection layers. You can prepare the projection layers following the same steps we went through for our initial layer prep. Here, I will just import the projection layers I already prepared to save time.

```r
proj.envs <- raster::stack(list.files(path = 'proj_envs', pattern = '.bil$', full.names = T))
proj.envs <- raster::stack(subset(proj.envs, c('bio15', 'bio18', 'bio2', 'bio3', 'elevation', 'mixed_other', 'slope')))   

plot(proj.envs[[1]])
```

For projection we just use the "SDMtune::predict()" function like we did the first time. But here we will provide our projection layers for the "data" argument.

```r
spat.proj <- SDMtune::predict(object = opt.mod.obj, data = terra::rast(proj.envs), 
                              type = 'cloglog', clamp = T, progress = T) %>% raster()

# Lets plot out the model
plot(spat.proj)
```


![proj](https://github.com/yucheols/ENMs_In_R/assets/85914125/0c9a7296-99cd-4159-be0d-27ae91e69ab4)


We can also do a ggplot-style plot:
```r
gplot(spat.proj) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = rev(terrain.colors(1000)),
                       na.value = NA,
                       name = 'Suitability') +
  xlab('Long') + ylab('Lat') +
  theme_dark()
```
![proj_gg](https://github.com/yucheols/ENMs_In_R/assets/85914125/6c5a7756-473c-45e6-beb0-b8b8338f70b5)


Since we are predicting the model to a different area than used to train our model, there might be some extrapolation happening with our prediction. When extrapolation happens, this essentially means that the model is predicting to the values outside the range of values of the original data. Habitat suitability predicted in areas with high extrapolation should be interpreted with caution. But how do we assess extrapolation risk? one way to do it is by calculating MESS (Multivariate Environmental Similarity Surface). This can be done using the dismo package.

```r
# Let's prepare data for MESS. We first need our projection layers
print(proj.envs)

# We also need "reference values" extracted from the layers used for original model calibration
print(envs)

ref.val <- raster::extract(envs, occs) %>% as.data.frame()
head(ref.val)

# Let's run MESS
mess <- dismo::mess(x = proj.envs, v = ref.val, full = T)
```

Let's plot the MESS raster. You need the pals package loaded to be able to use the "ocean.thermal" palette.
```r
gplot(mess$mess) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = rev(as.vector(ocean.thermal(22))),
                       na.value = 'transparent',
                       name = 'MESS',
                       breaks = c(-10, -260),
                       labels = c('Low', 'High'),
                       trans = 'reverse') +
  xlab('Long') + ylab('Lat')
```
The output looks like this.


![MESS](https://github.com/yucheols/ENMs_In_R/assets/85914125/cbfa46b7-1723-4daf-9abc-999adf345436)

