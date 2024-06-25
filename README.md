# Ecological niche modeling in R
### ENMs in R hands-on workshop 
- 1st installment: 28 Feb 2024 @ Lab. of Animal Behaviour and Conservation, Nanjing Forestry University, China
- 2nd installment: 13 Jun 2024 @ Yanbian University, China
- 3rd installment: 1 July 2024 @ Laboratory of Herpetology, Kangwon National University, South Korea

## Software and package dependencies
- _R (version 4.2.2)_: Programming language used in these tutorials
- SDMtune (version 1.3.1): Core niche modeling functions
- ENMwrap (version 1.0.0): Looper for modeling multiple species
- ENMeval (version 2.0.4): Generation of cross-validation folds
- megaSDM (version 2.0.0): Occurrence data collection
- humboldt (version 1.0.0.420121): Occurrence data thinning
- dismo (version 1.3.14): Niche modeling functions
- plyr (version 1.8.8): Data processing
- dplyr (version 1.1.0): Data processing
- readr (version 2.1.4): Data processing
- MASS (version 7.3.58.2): Generation of a density raster 
- raster (version 3.6.14): GIS and raster data processing
- terra (version 1.7.65): GIS and raster data processing
- sf (version 1.0.14): GIS data processing
- ggplot2 (version 3.4.1): General data visualization
- rasterVis (version 0.51.5): Raster data visualization
- pals (version 1.8): Expansion of the color palette for ggplot2
- caret (version 6.0.93): Correlation test

## Software and package installation
- R installation: https://cran.r-project.org/bin/windows/base/

- RStudio installation: https://posit.co/download/rstudio-desktop/

- Installation of packages hosted on CRAN
```r
pkg.list <- c('SDMtune', 'ENMeval', 'dismo', 'plyr', 'dplyr', 'readr', 'MASS', 'raster', 'terra', 'ggplot2', 'rasterVis', 'sf', 'pals', 'caret')

install.packages(pkg.list) 
```

- Installation of packages not hosted on CRAN
```r
## install the devtools package to enable the installation of packages from non-CRAN repositories
install.packages('devtools')

## install megaSDM
devtools::install_github("brshipley/megaSDM", build_vignettes = TRUE)

## install humboldt
devtools::install_github("jasonleebrown/humboldt")

## install ENMwrap
devtools::install_github("yucheols/ENMwrap")
```


