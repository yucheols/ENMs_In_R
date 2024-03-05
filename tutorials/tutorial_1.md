# ENMs in R hands-on practical session: Tutorial 1
#### by Yucheol Shin (Department of Biological Sciences, Kangwon National University, Republic of Korea)
28 Feb 2024
@ Laboratory of Animal Behaviour and Conservation, Nanjing Forestry University


## 1. Before we start: Why run ENMs in R?
Let's start our session by asking this question: Why run ENMs in R? After all, it seems pretty difficult (and indeed intimidating) to write codes to run the models instead of using other available softwares. At least that's how I felt when I started learning ENMs. So I started by learning the MaxEnt Java software (MaxEnt GUI). It is a point-and-click sofware that is user-friendly and easy to use. It looks something like this:

![mxgui](https://github.com/yucheols/ENMs_In_R/assets/85914125/9ab54b80-ac74-4c1c-88fe-d01dffbeac85)



It was great. But then there were some persistent issues that bothered me. First, I had to jump between three different softwares to prepare the data. First, I had to use GIS to crop the raster data and convert it into an ASCII format (because the MaxEnt GUI does not recognize the regular GeoTIFF rasters). And I then needed R to sample background data and fix errors in the ASCII files if there were any. Then I would use the MaxEnt GUI to run the models and then again go to GIS to plot the model outputs.

This was okay at first, but it quicky became frustrating, and small inconsistencies between softwares really strated to annoy me. In addition, some of the published model evaluation strategies were simply not available in the MaxEnt GUI. So at that point I decided to learn how to run ENMs in R. I do not regret this decision one bit.

This is my personal story, but also on a practical note, now there are TONS of ENM packages in R to choose from, and new ones are still being published. And the vast libraries of R mean that you can do spreadsheet handling, GIS, modeling, plotting, and other associated analyses in one integrated environment. Also, since you are the one doing the coding, you can customize your workflow in a way that is most convenient to you. 

#### In short, R provides a one-stop shop to prepare and organize your data, run ENMs, and make publication-quality plots with vast degree of flexibility. That is pretty cool, right?

## 2. A (very) basic workflow of presence-background ENMs
Presence-background ENM algorithms require the presence and background datasets (as its name implies), as well as environmental predictors, as inputs. Probably the most popular algorithm out there is MaxEnt, and it is the algorithm used here as well. Below is a very basic illustration of how the presence-background ENMs work. We will keep this workflow and its key steps in mind as we navigate the codes.  

![ENM_workflow](https://github.com/yucheols/ENMs_In_R/assets/85914125/32e1545b-b321-4c1e-9dea-e376458c778b)


The processes in rectangles are what I think of as the "key steps" - the steps I always go through when running ENMs, and the ones in grey ovals are what I call the "optional steps" - you can choose to run them or not depending on your research questions.

Of course, this is an oversimplification of the whole process, and I'm sure there are multiple ways to visualize it. But at least these are the broad steps I think about as I run ENMs in R. There are multiple steps involved and it is easy to lose track in the codes, especially if you are just learning R and ENMs. So it always helps to have a simplified workflow as a reference. 


## 3. Input data types and sources
Below are some of the basic input data types for presence-background ENMs.

1) Species occurrence data: Can be obtained through public databases such as GBIF and VertNet, as well as personal/institutional survey records.
2) Background points: Can be sampled using R or GIS.
3) Climate: Can be obtained from public databases such as WordClim, CHELSA, ENVIREM, etc. Or you can make your own layers in GIS using climate data.
4) Topography: Can be obtained from public databases, but can also be made in GIS (e.g. slope).
5) Land cover: Can be obtained from public databases such as EarthEnv.
6) Other: you may also consider solar radiation, potential evaporation, soil chemistry, distance to a certain environmental feature etc. These layers can either be obtained from public DBs or you can make them in GIS.

## 4. Species used in this tutorial
In this tutorial, we will use the Korean water toad (Bufo stejengeri) as an example organism for niche modeling. This species can be found in the mountains of northeastern China and the Korean Peninsula. The species is considered an ecological specialist because it is highly dependent on the mountain creeks and surrounding forests for survival. They overwinter underwater, usually in male-female pair in amplexus. Below you can see what the species and its habitat look like.

![bstej](https://github.com/yucheols/ENMs_In_R/assets/85914125/46011183-ce5c-4406-8fc0-e5151e57df85)
![habitat](https://github.com/yucheols/ENMs_In_R/assets/85914125/24c3116f-5e48-4d04-9326-8e2a8aa7ac5d)
(Photographed by Yucheol Shin)

#### Now let's move on to the next tutorial and start the modeling steps! 


