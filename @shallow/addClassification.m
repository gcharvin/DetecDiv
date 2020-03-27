function addClassification(obj)

% get the number of exisiting classification
clas=obj.processing.classification;
n=numel(clas);

if n==0
    obj.processing.classification=classi;
end

% ask user which method he wants to use
prompt='Please enter the name of the classification; Default: myclassi';
name= input(prompt,'s');
if numel(name)==0
    name='myclassi';
end


str=which('shallowNew.m');
[pth file ext]=fileparts(str);
str=[pth '/classification/classlist.mat'];
load(str);
disp(classlist)



prompt='Please enter the number associated with the classification you wish to do ? Default:1';
classitype= input(prompt);
if numel(classitype)==0
    classitype=1;
end

prompt='Please enter the channel on which to operate the classification ? Default:1';
channeltype= input(prompt);
if numel(channeltype)==0
    channeltype=1;
end

% create new classi object

pth=[obj.io.path '/' obj.io.file];

if classitype >0 && classitype< size(classlist,2) % user chose a correct method
    
    obj.processing.classification(n+1) = classi(pth,name,n+1);
    obj.processing.classification(n+1).typeid=classitype;
    obj.processing.classification(n+1).description=[classlist{classitype,2} ' -' classlist{classitype,3}];
    obj.processing.classification(n+1).category=classlist{classitype,4};
    obj.processing.classification(n+1).channel=channeltype;
    
else
    disp('Error : wrong classification type number!');
end

% add training data


prompt='Please enter the ROIs tu use as training sets: [FOV1 FOV1 FOV2; ROI1 ROI2 ROI1]; Default: [1 1 1; 1 2 3] ';
rois= input(prompt);

if numel(rois)==0
    rois=[1 1 1; 1 2 3];
end

obj.processing.classification(n+1).addTrainingData(rois);

% copy dedicated ROIs to local classification folder and change path

cc=1;
for i=1:size(rois,2)
    roitocopy=obj.fov(rois(1,i)).roi(rois(2,i));
    
    obj.processing.classification(n+1).roi(cc)=roi('',[]);
    
    roitocopy.load;
    
    obj.processing.classification(n+1).roi(cc)=propValues(obj.processing.classification(n+1).roi(cc),roitocopy);
    
    
    obj.processing.classification(n+1).roi(cc).path = obj.processing.classification(n+1).path;
    
    
    obj.processing.classification(n+1).roi(cc).save;
    obj.processing.classification(n+1).roi(cc).clear; 
        cc=cc+1;   
end

%


    function newObj=propValues(newObj,orgObj)
        pl = properties(orgObj);
        for k = 1:length(pl)
            if isprop(newObj,pl{k})
                newObj.(pl{k}) = orgObj.(pl{k});
            end
        end
    

