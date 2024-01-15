#### ENMs in R tutorials ::: hands-on workshop @NJFU Lab of Animal Behaviour and Conservation ::: Feb 2024
#### In this workshop, you will learn how to implement all the necessary steps of niche modeling entirely in R

#### We will use the Korean water toad (Bufo stejnegeri) as an example. This is a forest-dwelling specialist adapted to mountain streams.

# NOTE: it is always a good idea to break down your workflow into "parts". I do this by adding 5 "#" signs at both sides of my comment.
# This will enable you to collapse your workflow into organize chunks.
# You will see this workflow is formatted into "##### PART 1 ::: blah blah #####", "##### PART 2 ::: blah blah #####" and so on.

#######################################################  The workflow starts here  ######################################################
## load packages
library(terra)
library(raster)
library(dplyr)
library(SDMtune)
library(ENMeval)
library(extrafont)
library(rasterVis)
library(ggplot2)

## run the codes below ONCE ONLY == after running them once, lock them with "#" so that they are recognized as comments, not codes 
#dir.create('climate')
#dir.create('topo')
#dir.create('land')
#dir.create('env_processed') # to contain the processed raster layers

#####  PART 1 ::: load and prepare environmental data  #####
