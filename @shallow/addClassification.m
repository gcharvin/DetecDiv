function addClassification(obj)

% get the number of exisiting classification
clas=obj.processing.classification;
n=numel(clas);

if n==0
    obj.processing.classification=classi;
end

% ask user which method he wants to use
prompt='Please enter the name of the classification (Default: myclassi): ';
name= input(prompt,'s');
if numel(name)==0
    name='myclassi';
end


str=which('shallowNew.m');
[pth file ext]=fileparts(str);
str=[pth '/classification/classlist.mat'];
load(str);
disp(classlist)



prompt='Please enter the number associated with the classification you wish to do ? (Default:1): ';
classitype= input(prompt);
if numel(classitype)==0
    classitype=1;
end

if strcmp(classlist{classitype,2},'Cell segmentation')
  
    
end

disp('For object classification, you need to provide 1 channel for images and 1 for objects');
prompt='Please enter the channel(s) on which to operate the classification ? (Default:1): ';
channeltype= input(prompt,'s');
if numel(channeltype)==0
    channeltype=1;
else
   channeltype=str2num(channeltype); 
end


if ~strcmp(classlist{classitype,2},'Cell segmentation') % if cell segmentation, then class number is bacjground and cell by default
   
prompt='Please enter the classes names that you want  (Default: class1 class2): ';
classes= input(prompt,'s');

if isempty(classes)
   % 'ok'
    classes=['class1 class2'];
end
else
     classes=['background cell'];
end

classes = textscan(classes,'%s','Delimiter',' ')';
if numel(classes)==0
    classes={};
end

classes=classes{1};

disp('Classes entered:')
disp(classes);

% create new classi object

pth=[obj.io.path '/' obj.io.file];

if classitype >0 && classitype<= size(classlist,1) % user chose a correct method
    
    obj.processing.classification(n+1) = classi(pth,name,n+1);
    obj.processing.classification(n+1).typeid=classitype;
    obj.processing.classification(n+1).description=[classlist{classitype,2} ' -' classlist{classitype,3}];
    obj.processing.classification(n+1).category=classlist{classitype,4};
    obj.processing.classification(n+1).classifyFun=classlist{classitype,6}{1};
    obj.processing.classification(n+1).trainingFun=classlist{classitype,5}{1};
    obj.processing.classification(n+1).channel=channeltype;
    obj.processing.classification(n+1).classes=classes;
    obj.processing.classification(n+1).colormap=shallowColormap(numel(classes));
else
    disp('Error : wrong classification type number!');
    return;
end

% add training data

addROIToClassification(obj,n+1);


