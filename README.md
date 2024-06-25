# Ecological niche modeling in R
### ENMs in R hands-on workshop 
- 1st installment: 28 Feb 2024 @ Lab. of Animal Behaviour and Conservation, Nanjing Forestry University, China
- 2nd installment: 13 Jun 2024 @ Yanbian University, China
- 3rd installment: 1 July 2024 @ Laboratory of Herpetology, Kangwon National University, South Korea

## Software and package dependencies
- R (version 4.2.2)
- SDMtune (version 1.3.1)
- ENMwrap (version 1.0.0)
- ENMeval (version 2.0.4)
- megaSDM (version 2.0.0)
- humboldt (version 1.0.0.420121)
- dismo (version 1.3.14)
- plyr (version 1.8.8)
- dplyr (version 1.1.0)
- readr (version 2.1.4)
- MASS (version 7.3.58.2)
- raster (version 3.6.14)
- terra (version 1.7.65)
- sf (version 1.0.14)
- ggplot2 (version 3.4.1)
- rasterVis (version 0.51.5)
- pals (version 1.8)
- caret (version 6.0.93)

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

## How to download codes and data
1) Click the green button named "Code" on the top right part of this repository
![cap1](https://github.com/yucheols/ENMs_In_R/assets/85914125/667bf6f7-ea21-4aa6-b51a-f83e7ff8477c)

2) Click "Download ZIP" to download all the codes and associated data as a .zip file
![cap2](https://github.com/yucheols/ENMs_In_R/assets/85914125/eaaebabe-cc1e-4cab-8be1-eb81bbb77bba)

