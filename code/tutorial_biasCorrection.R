#######  bias correction
# be sure to use the raster package here instead of terra == this is because of the use of "OccurrenceCollection" function 
# in the megaSDM package
library(raster)
library(MASS)
library(megaSDM)
library(plyr)
library(dplyr)
library(readr)
library(SDMtune)
library(rasterVis)
library(ggplot2)

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

## Run this code ONCE to create a folder to put that background points in
#dir.create('bg')

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

## Let's thin this down with 1km thinning distance == reload enviornmental data if you see errors
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

## sample bias corrected background points
bg2 <- xyFromCell(bias.layer,
                  sample(which(!is.na(values(subset(envs, 1)))), 10000,
                         prob = values(bias.layer)[!is.na(values(subset(envs, 1)))])) %>% as.data.frame()

colnames(bg2) = colnames(occs)
head(bg2)

## Let's see how the background selection has changed compared to the random background
par(mfrow = c(1,2))

plot(envs[[1]], main = 'Random', axes = F, legend = F)
points(bg, col = 'blue')

plot(envs[[1]], main = 'Bias-corrected', axes = F, legend = F)
points(bg2, col = 'blue')


## Now we will fit a MaxEnt model with the same feature and regularization as the model we've made in the previous tutorial.
## That model was made from LQHP features + regularization of 1

## Let's partition the data
cvfolds2 <- ENMeval::get.randomkfold(occs = occs, bg = bg2, kfolds = 10)

## Let's prepare our SWD object
sp.data2 <- prepareSWD(species = 'Bufo stejnegeri', env = terra::rast(envs), p = occs, a = bg2, verbose = T)

## Let's fit the model
bias.cor.mod <- SDMtune::train(method = 'Maxent', data = sp.data2, folds = cvfolds2, fc = 'lqhp', reg = 1.0,
                               progress = T, iter = 5000, type = 'cloglog')

## prediction
bias.cor.pred <- SDMtune::predict(object = bias.cor.mod, data = terra::rast(envs), type = 'cloglog', clamp = T, progress = T) %>% raster()
plot(bias.cor.pred)

## lets compare this model side-by-side with the previous model
preds <- raster::stack(pred, bias.cor.pred)
names(preds) = c('Random', 'Bias-corrected')

gplot(preds) +
  facet_wrap(~ variable) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  
  scale_fill_gradientn(colors = rev(terrain.colors(1000)),
                       na.value = 'transparent',
                       name = 'Suitability') +
  xlab('Long') + ylab('Lat') +
  theme_dark()
