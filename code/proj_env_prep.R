# Japan polygon
jp <- sf::st_read('E:/Asia_shp/Japan/JPN_adm0.shp')

# climate
proj_clim <- raster::stack(list.files(path = 'climate', pattern = '.tif$', full.names = T))  # import
proj_clim <- raster::crop(proj_clim, extent(jp))                            # crop == crop to geographic extent
proj_clim <- mask(proj_clim, jp)                            # mask == cut along the polygon boundary ("cookie cutter")

# topo
proj_topo <- raster::stack(list.files(path = 'topo', pattern = '.tif$', full.names = T))
proj_topo <- crop(proj_topo, extent(jp))
proj_topo <- mask(proj_topo, jp)

names(proj_topo) = c('elevation', 'slope')  # rename variable names to something shorter

# land cover
proj_land <- raster('land/mixed_other.tif')
proj_land <- crop(proj_land, extent(jp))
proj_land <- mask(proj_land, jp)

### stack into one object == use "c()" for the terra equivalent of the "raster::stack()"
proj_envs <- raster::stack(proj_clim, proj_topo, proj_land)

# export projection layers
for (i in 1:nlayers(proj_envs)) {
  layer <- proj_envs[[i]]
  file_name <- paste0('proj_envs/', names(proj_envs)[i], '.bil')
  writeRaster(layer, filename = file_name, overwrite = T)
}
