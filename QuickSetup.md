![DetecDiv logo](https://github.com/gcharvin/DetecDiv/blob/master/Tutorial/detecDiv_logo-01.png)

# DetecDiv quick setup guide #

## Installation procedure ## 

You need Matlab R2019b installed with the following TB:

Image Processing Toolbox  
Deep Learning Toolbox
Computer Vision Toolbox
Bugfix: the classify function of the @DAGNetwork class needs to be patched. On line 172 :
remove the " ' " after scores{ii} in the arguments of undummify function

---------------------

## Create/Save a project ##

```myproject= shallowNew```
 (then select a project name and place to save it)

```projet=shallowLoad;```
To load a project (if you just created one, it will be loaded as ***myproject*** in the variable workspace

```projet.addData;```
To add images to the project. Follow the indications.

```projet.setPattern;```
To set a typical pattern for future automatic cropping (example: select a trap)

```projet.identifyRois;```
To identify the ROIs based on the setPattern

```projet.saveCroppedImages;```
To save the identified Rois into standalone .mat files

```projet.addClassification;```
To create a new classification

## Option A: Image sequence classifier ##
Choose (4): blablabla

```projet.processing.classification(1).addROI(projet.fov(1),projet.fov(1),1:10];```

## Option B: Semantic segmentation ##


