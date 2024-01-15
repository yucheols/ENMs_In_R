# ENMs in R hands-on practical session
#### by Yucheol Shin (Department of Biological Sciences, Kangwon National University, Korea)
Feb dd 2024
@ Laboratory of Animal Behaviour and Conservation, Nanjing Forestry University


## 1. Before we start: Why run ENMs in R?
Let's start our session by asking this question: Why run ENMs in R? After all, it seems pretty difficult (and indeed intimidating) to write codes to run the models instead of using other available softwares. At least that's how I felt when I started learning ENMs. So I started by learning the MaxEnt Java software (MaxEnt GUI). It is a point-and-click sofware that is user-friendly and easy to use. It was great. But then there were some persistent issues that bothered me. First, I had to jump between three different softwares to prepare the data. First, I had to use GIS to crop the raster data and convert it into an ASCII format (because the MaxEnt GUI does not recognize the regular GeoTIFF rasters). And I then needed R to sample background data and fix errors in the ASCII files if there were any. Then I would use the MaxEnt GUI to run the models and then again go to GIS to plot the model outputs.

This was okay at first, but it quicky became frustrating, and small inconsistencies between softwares really annoyed me. In addition, some of the published model evaluation strategies were simply not available in the MaxEnt GUI. So at that point I decided to learn how to run ENMs in R. I do not regret this decision one bit.

This is my personal story, but also on a practical note, now there are TONS of ENM packages in R to choose from, and new ones are still being published. And the vast libraries of R mean that you can do spreadsheet handling, GIS, modeling, plotting, and other associated analyses in one integrated environment. Also, since you are the one doing the coding, you can customize your workflow in a way that is most convenient to you. 

#### In short, R provides a one-stop shop to prepare and organize your data, run ENMs, and make publication-quality plots with vast degree of flexibility. That is pretty cool, right?

## 2. A (very) basic workflow of presence-background ENMs
Presence-background ENM algorithms require the presence and background datasets (as its name implies), as well as environmental predictors, as inputs. Probably the most popular algorithm out there is MaxEnt, and it is the algorithm used here as well. Below is a very basic illustration of how the presence-background ENMs work. We will keep this workflow and its key steps in mind as we navigate the codes.  

![ENM_workflow](https://github.com/yucheols/Lycodon_ENM_ver2/assets/85914125/4afb2c4c-7576-4f1c-9bd3-ffc2a44863c3)

The processes in rectangles are what I think of as the "key steps" - the steps I always go through when running ENMs, and the ones in grey ovals are what I call the "optional steps" - you can choose to run them or not depending on your research questions.

Of course, this is an oversimplification of the whole process, and I'm sure there are multiple ways to visualize it. But at least these are the broad steps I think about as I run ENMs in R. There are multiple steps involved and it is easy to lose track in the codes, especially if you are just learning R and ENMs. So it always helps to have a simplified workflow as a reference. 


#### Also, let us look at the data types needed to run ENMs and where to get them.....
Below are some of the basic input data types for presence-background ENMs.

1) Species occurrence data: Can be obtained through public databases such as GBIF and VertNet, as well as personal/institutional survey records.
2) Background points: Can be sampled using R or GIS.
3) Climate: Can be obtained from public databases such as WordClim, CHELSA, ENVIREM, etc. Or you can make your own layers in GIS using climate data.
4) Topography: Can be obtained from public databases, but can also be made in GIS (e.g. slope).
5) Land cover: Can be obtained from public databases such as EarthEnv.
6) Other: you may also consider solar radiation, potential evaporation, soil chemistry, distance to a certain environmental feature etc. These layers can either be obtained from public DBs or you can make them in GIS.

## 3. Set up the working directory
Before diving in, we need to setup an environment to run the codes.

1) First, make sure to have both R and RStudio installed in your laptop.
2) Open RStudio and navigate to "File > New Project"
3) Select "New Directory > New Project"
4) Set the project name to "NJFU_ENMs_Workshop_2024"
5) Now you will be working within this directory for this workshop. 


## 4. Load packages and prepare data
The terra and raster packages are for raster data handling in R, dplyr is for data frame manipulation and filtering, SDMtune is used for core model fitting and predictions, 
ENMeval is used to generate spatial blocks, and extrafont, rasterVis and ggplot2 packages are used for plotting model outputs in R.

** Note: I used the raster package as a matter of personal preference while writing this code. But now it is recommended to use the terra package instead.

```r
## load libraries
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
#####  PART 1 ::: environmental data  #####
# set clipping extent
ext <- c(100, 132, 18, 42)

# clim
clim <- raster::stack(list.files(path = 'E:/env layers/worldclim', pattern = '.tif$', full.names = T))
clim <- raster::crop(clim, ext)
plot(clim[[1]])

names(clim) = c('bio1','bio10','bio11','bio12','bio13','bio14','bio15',
                'bio16','bio17','bio18','bio19','bio2','bio3','bio4',
                'bio5','bio6','bio7','bio8','bio9')

# elev 
elev <- raster('E:/env layers/elev_worldclim/wc2.1_30s_elev.tif')
elev <- raster::crop(elev, ext)
names(elev) = 'elev'

# slope == created from the elev layer cropped above
slope <- raster('slope/slope.tif')
plot(slope)

# land cover
land <- raster::stack(list.files(path = 'E:/env layers/land cover', pattern = '.tif', full.names = T))
land <- raster::stack(subset(land, c('cultivated', 'herb', 'shrubs', 'forest_merged')))
land <- raster::crop(land, ext)
names(land) = c('cultivated', 'herb', 'shrubs', 'forest')
```

## 5. Background data sampling

## 6. Variable selection

## 7. Data partitioning for model evaluation

## 8. Model tuning and optimal model selection

## 9. Response curves
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

## 10. Model prediction

## n. Model extrapolation
Here we will project the fitted model to the environmental conditions of California. This is an ecologically meaningless exercise but we will try this nonetheless to illustrate the concept of model transfer.

