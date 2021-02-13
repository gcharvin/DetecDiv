# Shallow rethinks image processing pipelines, adding deeplearning enabled classification tools for segmentation and event detection

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


```myproject.processing.classification(id).clearTraining``` to remove training data 
see function arguments for details 


#### Using classifications ####

```myproject.processing.classification(id).setClasses(classnames)```
allows the user to define and to reassign classes in the @classi object and dependencies (ROIs)
number of classes can be extended or decreased


```myproject.myproject.processing.classification(id).userTraining```
launches a GUI to set the ground truth using a specific ROI


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


```myproject.processing.classification(id).displayValidation```
loads a specific ROI along with the classification results and groundtruth if there are any
This also provides basic statistics about the classification


```myproject.processing.classification(id).stats```
compute and stores (as a txt file) the statistics associated with the classification and comparison
to groundtruth


```myproject.classifyData(classifid,roilist,option)```
allows one to start the classification referred to as classifid on the roilist; You can provide the classifier as an option, so that it is not loaded each time you run the function
