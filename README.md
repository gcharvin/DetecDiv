# shallow rethinks image processing pipelines, adding deeplearning enabled classification tools for segmentation and event detection

% Installation procedure %

You need Matlab R2019b installed with the following TB:


Image Processing Toolbox  
Deep Learning Toolbox
Computer Vision Toolbox


Bugfix: the classify function of the @DAGNetwork class needs to be patched. On line 172 :
remove the " ' " after scores{ii} in the arguments of undummify function


% Basic instructions %


Create/Save a project
---------------------

myproject= shallowNew

 (then select a project name and place to save it)

shallowSave(myproject)

(saves the project)

shallowLoad(path)

(loads the project located in path; if no path is provided, launches a dialog box to select the project)


Import Data
------------

myproject.addData

allows to add new fields of view (FOV) to the project


ROIs
----

myproject.fov(myfovid).view

allows to view the FOV myfovid and choose custom ROIs manually. For this, use the zoom & pan buttons and right click on the image

myproject.setPattern(myfovid,roiid,frameid)

uses a given FOV/ROI/frame to create a pattern to be used for automated ROI detection

myproject.identifyROIs(myfovid,frameid)

uses autocorrelation to identify all ROIs based on a given pattern in specific FOVs, using specific frame frameid

myproject.saveCroppedImages(myfovid,frameid)

writes 4D volumes (w x h x ch x time) in a subfolder of the the main analysis folder

myproject.fov(myfovid).roi(myroiid).view

allows to view the 4D volume in a GUI


Classification
--------------

myproject.addClassification

create a new classifier  ( @classi object)

myproject.processing.classification

is an array that contains all classifiers created

myproject.addClassification(index) will duplicate the object myproject.processing.classification(index) , where index the index of a valid classi object

myproject.addClassification(string) will import an existing classifier from the reposiotry , where index the index of a valid classi object.

myproject.removesClassification(id) will remove a classifier specified by the index id. 

myproject.addROIToCLassification(classifid)

add a series of ROIs to the classification classifid. By default this function is called when creating a classifier.

myproject.userTraining(classifid)

launches a GUI to train the classifier classifid using a specific ROIs

myproject.trainClassifier(classifid)

trains the classifier using the training defined by the user

myproject.formatDataForTraining(classifid)

formats data to be used by the classifier; this function is called first when launching the trainClassifier function

myproject.validateTrainingData(classifid)

uses the classifier to classify ROIs associated with user training in order to compare user training to classification results

myproject.classifyData(classifid,roilist,option)

allows one to start the classification reffered to as classifid on the roilist; You can provide the classifier as an option, so that it is not loaded each time you run the function
