# ENMs in R hands-on practical session: Tutorial 2
#### by Yucheol Shin (Department of Biological Sciences, Kangwon National University, Korea)
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


```r
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
```

## Part 2. Occurrence data collection
```r
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
```

## Part 3. Background data sampling
```r
bg <- dismo::randomPoints(mask = envs[[1]], n = 10000, p = occs[, c(2,3)], excludep = T) %>% as.data.frame()
points(bg, col = 'blue')

head(bg)
colnames(bg) = colnames(occs[, c(2,3)])
```

## Part 4. Data partitioning for model evaluation
```r
cvfolds <- ENMeval::get.randomkfold(occs = occs, bg = bg, kfolds = 10)
```

## Part 5. Fitting candidate models and selecting the optimal model


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


## n. Model extrapolation



