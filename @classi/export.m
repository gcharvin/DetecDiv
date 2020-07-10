function export(classif)
% export classification to a given folder; 
% the whole @classi object is copied if a new repository is created
% otherwise, only the ROIs and training datasets are created 

% to do -->  import classif to existing project



str=which('shallowLoad');
[pth fle ext]=fileparts(str);
filename=[pth '/@classi/repository.txt'];
fileID=fopen(filename);
C = textscan(fileID,'%s');
fclose(fileID);
str=C{1}{10}(1:end-1); % contains the path to the classi repository

% now list all the classification variables available

l=dir(str);

id=[];
idstr={};
cc=1;

for i=1:numel(l)
    
    if l(i).isdir==1
        continue
    end
    
    id=[id cc];
    idstr(cc,1)={ i};
    idstr(cc,2)={ l(i).name};
    cc=cc+1;
end

disp(idstr)

classitype=0;

if numel(idstr)>0
    disp('Enter the existing classification number you wish to feed ?');
    prompt=' Type 0 if you want to create a new classification repository (Default:0): ';
    classitype= input(prompt);
    if numel(classitype)==0
        classitype=0;
    end
end

if classitype==0 % create a new repository
   prompt='Enter the name of the name of the repository to be created (default: myclassif) ';
    classiname= input(prompt,'s');
    if numel(classiname)==0
        classiname='myclassif';
    end
    mkdir(str,classiname);
    classiname2=[classiname '.mat'];
else
   classiname2= l(classitype).name;
   [pt classiname ext]=fileparts(classiname2);
end

%mkdirstr
%classitype

% now copy files associated with classification to appropriate folder and
% save classif. mat file


if classitype==0 % in this case copy all the information to the disk
  disp('A new classification repository has been created');
classification=classif;


%[classifpth classiffle ext]=fileparts(classifolder)
disp('Copying files and subfolders....Be patient !');
copyfile([classif.path '/*'],[str '/' classiname]);

disp('Adjusting path to transferred ROIs');

for i=1:numel(classif.roi)
    classification.roi(i).path=[str '/' classiname '/' classif.roi(i).id];
end

else % in this case, only training sets and ROIs will be copied 
    % first copy existing training set data 
    disp('Loading existing target classification....Be patient !');
    load([str '/' classiname2]); % classification variable
    
    %classif.roi
    disp('Copying training datasets....Be patient !');
    
    %copyfile([classif.path '/trainingdataset/*'],[str '/' classiname '/trainingdataset/']);
    
    % copy ROIs used for generating training sets, add ROI to target
    % classif and chage path ! 
    
    for i=1:numel(classif.roi)
        disp(['Copying ROI ' num2str(i) '/' num2str(numel(classif.roi)) '...']);
        
        notadd=0;
        
        if exist([str '/' classiname '/im_' classif.roi(i).id '.mat'])
           notadd=1;
           disp('ROI is already present at destination; overwriting....'); 
        end
        
      % aa= classif.roi(i).path
        
        copyfile([classif.roi(i).path '/im_' classif.roi(i).id '.mat'],[str '/' classiname '/im_' classif.roi(i).id '.mat']);
        
        if notadd==0
            disp('adding ROI to classif object....'); 
            n=numel(classification.roi);
            classification.roi(n+1)=classif.roi(i);
            classification.roi(n+1).path=[str '/' classiname '/'];
        end
    end
    
    % add ROIs to classification object
end

save([str '/' classiname2],'classification');



















