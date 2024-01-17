# ENMs in R hands-on practical session: Tutorial 2
#### by Yucheol Shin (Department of Biological Sciences, Kangwon National University, Korea)
Feb dd 2024
@ Laboratory of Animal Behaviour and Conservation, Nanjing Forestry University

## 1. Set up the working directory
Before diving in, we need to setup an environment to run the codes.

1) First, make sure to have both R and RStudio installed in your laptop.
2) Open RStudio and navigate to "File > New Project"
3) Select "New Directory > New Project"
4) Set the project name to "NJFU_ENMs_Workshop_2024"
5) Now you will be working within this directory for this workshop. 


## 2. Load packages and prepare data
The terra and raster packages are for raster data handling in R, dplyr is for data frame manipulation and filtering, SDMtune is used for core model fitting and predictions, 
ENMeval is used to generate spatial blocks, and extrafont, rasterVis and ggplot2 packages are used for plotting model outputs in R.

** Note: I used the raster package as a matter of personal preference while writing this code. But now it is recommended to use the terra package instead.

```r
## load packages
library(terra)
library(raster)
library(dplyr)
library(SDMtune)
library(ENMeval)
library(extrafont)
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

## 3. Background data sampling

## 4. Variable selection

## 5. Data partitioning for model evaluation

## 6. Model tuning and optimal model selection

## 7. Response curves
With SDMtune you can get a response curve for each variable using the "plotResponse()" function. But you may wish to further customize the plot for better visualization or publication. For that we can actually extract the data used to build response curves and customize the plot using ggplot2.

To pull out the data though, we need to make a little work around because "plotResponse()" will automatically print out a finished plot. We can use this little wrapper function I've made (called "respDataPull()") to extract response data:

```r
respDataPull <- function(model, var, type, only_presence, marginal, species_name) {
  
  plotdata.list <- list()
  
  for (i in 1:length(var)) {
    plotdata <- plotResponse(model = model, var = var[[i]], type = type, only_presence = only_presence, marginal = marginal)
    plotdata <- ggplot2::ggplot_build(plotdata)$data
    plotdata <- plotdata[[1]]
    
    plotdata <- plotdata[, c(1,2)]
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
broad.resp.data <- respDataPull(model = tune@models[[6]], 
                                var = c('bio1', 'bio12', 'bio14', 'bio3', 'bio5', 'cultivated', 'herb', 'shrub', 'slope'),
                                type = 'cloglog', only_presence = T, marginal = T, species_name = 'Lycodon')

print(broad.resp.data)
```

## 8. Model prediction

## n. Model extrapolation
Here we will project the fitted model to the environmental conditions of California. This is an ecologically meaningless exercise but we will try this nonetheless to illustrate the concept of model transfer.


