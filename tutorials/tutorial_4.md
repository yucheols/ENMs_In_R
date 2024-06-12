# ENMs in R hands-on practical session: Tutorial 4
#### by Yucheol Shin (PhD student, Richard Gilder Graduate School, American Museum of Natural History, USA)

- 1st installment: 28 Feb 2024 @ Laboratory of Animal Behaviour and Conservation, Nanjing Forestry University, China
- 2nd installment: 13 Jun 2024 @ Yanbian University, China
- 3rd installment: Lab. of Herpetology, Kangwon National University, South Korea. Dates TBD

## Generating ENMs for multiple species at once using the ENMwrap pipeline
In previous tutorials, we learned how to implement a single-species ecological niche modeling. However, sometimes we need to simultaneously generate ecological niche models for many different species.

## Part 0. Prepare the working environment and load packages
```r
# clear working environment
rm(list = ls(all.names = T))
gc()

# load packages
library(ENMwrap)
library(megaSDM)
library(raster)
library(dismo)
library(plyr)
library(dplyr)
library(readr)

# set random seed for reproducibility of random sampling elements
set.seed(333)
```

## Part 1. Prepare environmental data
```r
# mask polygon == Republic of Korea
poly <- terra::vect('poly/KOR_adm0.shp')

# load climate data
envs <- terra::rast(list.files(path = 'E:/env layers/worldclim', pattern = '.tif$', full.names = T))
names(envs) = c('bio1', 'bio10', 'bio11', 'bio12', 'bio13', 'bio14', 'bio15', 'bio16', 'bio17',
                'bio18', 'bio19', 'bio2', 'bio3', 'bio4', 'bio5', 'bio6', 'bio7', 'bio8', 'bio9')

# layer masking and processing
envs <- terra::crop(envs, terra::ext(poly))
envs <- terra::mask(envs, poly) %>% raster::stack()
raster::plot(envs[[1]])
```

We can export the processed layers for easier access later on if we want. Note that I'm exporting the files in .bil format to retain the layer names.

```r
# export processed
for (i in 1:nlayers(envs)) {
  r <- envs[[i]]
  name <- paste0('envs/processed/', names(envs)[i], '.bil')
  writeRaster(r, filename = name, overwrite = T)
}
```

## Part 2. Collect occurrence data
```r
spplist <- c('Bufo stejnegeri',
             'Bufo gargarizans',
             'Glandirana emeljanovi',
             'Hynobius leechii',
             'Kaloula borealis',
             'Pelophylax nigromaculatus',
             'Rana coreana',
             'Rana huanrenensis')

# get data
#OccurrenceCollection(spplist = spplist,
#                     output = 'occs_test_workflow/raw',
#                     trainingarea = envs[[1]])
```

Once we collect the occurrence points for each species, we can import all of the .csv occurrence files and compile them into a single dataframe. We can then separate this dataframe by species by applying the "filter" function of the *dplyr* package. We will also select longitude and latitdue columns only. We will then put the data for each species into a list object that we will call "occs_list". This list object will be fed to the "occs_thinner" function of the *ENMwrap* package.

```r
# compile raw data
occs_all <- list.files(path = 'occs_test_workflow/raw', pattern = '.csv', full.names = T) %>%
  lapply(read_csv) %>%
  plyr::rbind.fill() %>%
  dplyr::select('species', 'decimalLongitude', 'decimalLatitude')

colnames(occs_all) = c('species', 'long', 'lat')

# sort compiled data into two column (long, lat) dataframe by species
occs_list <- list(occs_all %>% filter(species == spplist[[1]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[2]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[3]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[4]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[5]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[6]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[7]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[8]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[9]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[10]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[11]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[12]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[13]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[14]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[15]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[16]]) %>% select(2,3),
                  occs_all %>% filter(species == spplist[[17]]) %>% select(2,3))
```

```r
# thin
thin <- occs_thinner(occs_list = occs_list, envs = envs[[1]], long = 'long', lat = 'lat', spp_list = spplist)

# export thinned occurrence data per species
for (i in 1:length(thin)) {
  file <- thin[[i]]
  write.csv(thin[[i]], paste0('occs_test_workflow/thinned/', spplist[[i]], '.csv'))
}
```

```r
##### part 3 ::: get background data ---------------------------------------------------
# get random background points
bg <- randomPoints(mask = envs[[1]], n = 10000) %>% as.data.frame()
colnames(bg) = c('long', 'lat')
head(bg)
```

```r
##### part 4 ::: select environmental variables ---------------------------------------------------
# may need to revise this part later on to better reflect species-specific climatic requirements....but this should be enough for now to test the workflow

# extract pixel values
vals <- raster::extract(envs, bg) %>% as.data.frame()
head(vals)

# generate correlation matrix
cormat <- cor(vals, method = 'pearson')
print(cormat)

# run correlation test
testcor <- caret::findCorrelation(cormat, cutoff = abs(0.7))
print(testcor)

# reduce the env dataset
envs.subs <- raster::dropLayer(envs, testcor) 
print(envs.subs)
```

```r
##### part 5 ::: test candidate models per species  ---------------------------------------------------

# fit models per species == may need to increase the feature class (fc) and regularization (rm) combinations for actual application
# for the code below (testing two features and two regularizations), it takes aproximately 2~3 minutes per species
testsp <- test_multisp(taxon.list = spplist,
                       occs.list = occs_list,
                       envs = envs.subs,
                       bg = bg,
                       tune.args = list(fc = c('LQ','LQHP'), rm = c(1, 1.5)),
                       partitions = 'block',
                       partition.settings = list(orientation = 'lat_lon'),
                       type = 'type1')

# check results
print(testsp$metrics)
print(testsp$models)
print(testsp$preds)
print(testsp$contrib)
print(testsp$taxon.list)

# plot predictions
# should fix the package code at some point to remove the rgdal and raster dependencies....so that I can directly use the SpatVector object loaded earlier....
# but I dont have enough time now so this will have to do
rok <- rgdal::readOGR('poly/KOR_adm0.shp')
plot_preds(preds = testsp$preds, poly = rok, pred.names = spplist)
```

