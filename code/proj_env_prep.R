jp <- sf::st_read('E:/Asia_shp/Japan/JPN_adm0.shp')

# climate
clim <- raster::stack(list.files(path = 'climate', pattern = '.tif$', full.names = T))  # import
clim <- raster::crop(clim, extent(jp))                            # crop == crop to geographic extent
clim <- mask(clim, jp)                            # mask == cut along the polygon boundary ("cookie cutter")

# topo
topo <- raster::stack(list.files(path = 'topo', pattern = '.tif$', full.names = T))
topo <- crop(topo, extent(jp))
topo <- mask(topo, jp)

names(topo) = c('elevation', 'slope')  # rename variable names to something shorter

# land cover
land <- raster('land/mixed_other.tif')
land <- crop(land, extent(jp))
land <- mask(land, jp)

### stack into one object == use "c()" for the terra equivalent of the "raster::stack()"
envs <- raster::stack(clim, topo, land)