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
xx

```projet.addData;```
xx

```projet.setPattern;```
xx

```projet.identifyRois;```
xx

```projet.saveCroppedImages;```
xx

```projet.addClassification;```
xx

```projet.processing.classification(1).addROI(projet.fov(1),projet.fov(1),1:10];```
