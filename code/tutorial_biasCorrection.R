#######  bias correction
library(MASS)
library(megaSDM)
library(plyr)
library(dplyr)
library(tidyverse)

## before going any further, let's check the data we are recycling from the previous tutorial.
print(envs)
print(occs)
print(poly)

## Let's collect occurrence points for our "target group". Since B. stejnegeri is an amphibian, we will use the total amphibian occurrence
## points recorded from the Korean Peninsula. This will serve as a proxy of the overall sampling effort for amphibians across the 
## Korean Peninsula.

## To easily collect our occurrence points, we will again use the megaSDM package.

## I need to run the three lines below to prevent encoding error from halting the occurrence collection process. But you may not need
## to run this on this your own device 
Sys.getlocale()
Sys.setlocale("LC_CTYPE", ".1251")
Sys.getlocale()


# make a list of species as an input for the megaSDM function
spplist <- c('Bombina orientalis', 
             'Bufo sachalinensis',
             'Bufo stejnegeri',
             'Dryophytes japonicus',
             'Dryophytes suweonensis',
             'Dryophytes flaviventris',
             'Glandirana emeljanovi',
             'Hynobius leechii',
             'Hynobius yangi',
             'Hynobius quelpaertensis',
             'Hynobius unisacculus',
             'Hynobius geojeensis',
             'Hynobius perplicatus',
             'Hynobius notialis',
             'Karsenia koreana',
             'Kaloula borealis',
             'Lithobates catesbeianus',
             'Onychodactylus koreanus',
             'Onychodactylus sillanus',
             'Pelophylax nigromaculatus',
             'Pelophylax nigromaculatus',
             'Rana uenoi',
             'Rana coreana',
             'Rana huanrenensis')

## collect occurrences
targ.pts <- OccurrenceCollection(spplist = spplist,
                                 output = 'bg',
                                 trainingarea = extent(envs[[1]]))

## Let's compile the occurrence points
targ.pts <- list.files(path = 'bg', pattern = '.csv', full.names = T) %>%
  lapply(read_csv) %>%
  rbind.fill %>%
  dplyr::select(4,6,5)

colnames(targ.pts) = c('species', 'long', 'lat')
head(targ.pts)

## Let's thin this down with 1km thinning distance
targ.thin <- thinData(coords = targ.pts[, c(2,3)], env = terra::rast(envs[[1]]), x = 'long', y = 'lat', verbose = T, progress = T)

## Plot it out
plot(envs[[1]])
points(targ.thin, col = 'blue')

## turn this into a kernel density raster. This is the "bias file" used in the MaxEnt GUI
ras <- rasterize(targ.thin, envs, 1)
plot(ras)

pres <- which(values(ras) == 1)
locs <- coordinates(ras)[pres, ]

kde <- kde2d(locs[, 1], locs[, 2],
             n = c(nrow(ras), ncol(ras)),
             lims = c(extent(envs)[1], extent(envs)[2], extent(envs)[3], extent(envs)[4]))

kde.ras <- raster(kde, envs)
kde.ras2 <- resample(kde.ras, envs)
bias.layer <- mask(kde.ras2, poly)
plot(bias.layer)


