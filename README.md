<div id="top"></div>

<!-- PROJECT SHIELDS -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]


## Installation procedure ## 

You need Matlab R2019b installed with the following TB:


Image Processing Toolbox  
Deep Learning Toolbox
Computer Vision Toolbox


Bugfix: the classify function of the @DAGNetwork class needs to be patched. On line 172 :
remove the " ' " after scores{ii} in the arguments of undummify function


## Basic instructions ##


### Create/Save a project ###
---------------------

```myproject= shallowNew```
 (then select a project name and place to save it)

```shallowSave(myproject)```
(saves the project)

```shallowLoad(path)```
(loads the project located in path; if no path is provided, launches a dialog box to select the project)


### Import Data ###
------------

```myproject.addData```
allows to add new fields of view (FOV) to the project


### ROIs ###
----

```myproject.fov(myfovid).view```
allows to view the FOV myfovid and choose custom ROIs manually. For this, use the zoom & pan buttons and right click on the image

```myproject.setPattern(myfovid,roiid,frameid)```
uses a given FOV/ROI/frame to create a pattern to be used for automated ROI detection


```myproject.identifyROIs(myfovid,frameid)```
uses autocorrelation to identify all ROIs based on a given pattern in specific FOVs, using specific frame frameid


```myproject.saveCroppedImages(myfovid,frameid)```
writes 4D volumes (w x h x ch x time) in a subfolder of the the main analysis folder


```myproject.fov(myfovid).roi(myroiid).view```
allows to view the 4D volume in a GUI


```myproject.fov(myfovid).roi(myroiid).traj(classistr)```
shows the "trajectory", ie the sequences of classification done according to a given classifier in a @classi object
classistr= project.processing.classification(id).strid;
Also works with ROIs that belong to @classi objects



### Classification ###
--------------

#### Adding a new classification ####

```myproject.addClassification```
create a new classifier  ( @classi object)
in this case, no ROI is imported in the classi object


```myproject.processing.classification```
is an array that contains all classifiers created


```myproject.addClassification(classiobject)``` will duplicate the @classi object 
user is asked whether to import ROIs included in the original classi object


```myproject.addClassification(string)``` will import an existing classifier (string) from a repository
%% not really implemented yet%%



#### Removing a classification ####

```myproject.removeClassification(id)``` will remove a classifier specified by the index id.



#### Adding ROIs a to a classification ####

```myproject.processing.classification(id).addROI(@classi object OR @fov object, optional: ROIs IDs)```
adds ROIs to the classification myproject.processing.classification(id).
ROIs may come either from a @fov or from an exisiting @classi object
This function will preserve training sets and reformat it if the number of classes are different
ex:  myproject.processing.classification(1).addROI(myproject.fov(1))
myproject.processing.classification(1).addROI(myproject.processing.classifiction(1).roi(1))

```myproject.processing.classification(id).clearTraining``` to remove training data 
see function arguments for details 


#### Using classifications ####

```myproject.processing.classification(id).setClasses(classnames)```
allows the user to define and to reassign classes in the @classi object and dependencies (ROIs)
number of classes can be extended or decreased


```myproject.myproject.processing.classification(id).userTraining```
launches a GUI to set the ground truth using a specific ROI


```myproject.fov(myfovid).roi(myroiid).fillTraining()```
Annotate classes of the training of the ROI, using the last annotated frame as template. Ex: [1 0 0 0 2 0 0 3] --> [1 1 1 1 2 2 2 3]


```myproject.myproject.processing.classification(id).formatDataForTraining```
formats data to be used by the classifier;
this must be done before launching the training procedure


```myproject.myproject.processing.classification(id).setTrainingParam```
request parameters values for training the classifier; default values can be entered


```myproject.processing.classification(id).trainClassifier```
1) asks whether the trainingset needs to be formatted
2) asks whether training parameters must be updated
3) then trains the classifier


```myproject.processing.classification(id).loadClassifier```
loads the classifier associated with @classi object in the workspace


```myproject.processing.classification(id).validateTrainingData(optional: classifier)```
uses the classifier of the @classi object (optional: provide a classifier) to classify ROIs used to build the groundtruth in order to compare with classification results

```myproject.classifyData(classifid,roilist,option)```
allows one to start the classification referred to as classifid on the roilist; You can provide the classifier as an option, so that it is not loaded each time you run the function

```myproject.processing.classification(id).displayValidation```
loads a specific ROI along with the classification results and groundtruth if there are any
This also provides basic statistics about the classification


```myproject.processing.classification(id).stats```
compute and stores (as a txt file) the statistics associated with the classification and comparison
to groundtruth

```out=classifyData2(test.processing.classification(2),test.processing.classification(2).roi(1:2),'Classifier',classifier,'Parallel')```


### Extract RLS ###
---------------------
```rls=measureRLS2(theo.processing.classification(1),theo.processing.classification(1).strid)```

```measureRLS3(theoRLS.processing.classification(1),theoRLS.fov(1).roi(1:100))```

```statRLS(rls)```
### Extract signal from ROIs ###
---------------------
```myproject.fov(1).extractFluo(cf arguments below)``` outdated
or
```myproject.processing.classification(id).extractFluo(cf arguments below)``` outdated
Extract signal from the ROIs of the fov or classi object. 
Arguments:
'Method': 'maxPixels' computes the average of the kMaxPixels. // 'mean'
'Channels'
'Frames'
'Rois'

```myproject.fov(1).detectFluoPattern('Channels',[4,5])```
Arguments:
*'Method': 'full' check .fluo.full.maxf // 'mean' checks the fluo.meanf
*'Channels'
*'Frames'
*'Rois'
*'fluoThreshold'
*'frameThreshold' number of frames to be above fluoThreshold

### Exporting movies or image sequences ###
------------------------
Coming soon/In construction
```myproject.fov.export('Frames',1:5,'Framerate',10,'FontSize',96,'Levels',[4000 14000],'DrawROIs',[],'Drift')```

```myproject.processing.classification(3).export('Mosaic',1:9,'Name','test','Training','Results','Levels',[6000 20000],'Framerate',10,'Title','fob1','RLS')```

```myproject.fov(1).roi(1).export('Frames',[1:10:150],'Sequence',3,'Levels',{[5000 30000]},'Background',[1 1 1],'Text',[0 0 0],'Training','Results','Classification',rls.processing.classification(1),'RLS')``` export sequence of Frames

### Make independant classifications ###
---------------------
```list = listRepositoryClassi;``` will create a .txt file in the default matlab folder, containing the indicated path for a folder in which you will put all your desired independant classifications. In this folder, you will be able to create new classi, export existing classi into shallow projects, update existing classi, import classi into it, and add/update ROIs to existing classi.
to be continued...

### Plot ###

```plotRLS({shallowObj.fov(1).roi(1:50);shallowObj.fov(1).roi(51:100)},'Comment',{'test1: ','test2: '})```
plots the RLS from the rois shallowObj.fov(1).roi(1:50) versus the rois shallowObj.fov(1).roi(51:100), measured by ```measureRLS3```.

### Misc ###
---------------------
```myproject.run('roilist',roilist,'args',{'argument Name1 of the method',argument1,'argumentname2',argument2});``` applies the roiMethod to roilist, with arguments args.




---------------------
---------------------
---------------------
### List of methods ###
---------------------

## roi ##
```.combineChannels```, arguments:{'channels',[1 2 3],'rgb',{[1 0 0],[0 1 0],[0 0 1]} combines the channels 1 2 3 to create a new rgb channel with intensities [1 0 0],[0 1 0],[0 0 1] for the respective channels.
