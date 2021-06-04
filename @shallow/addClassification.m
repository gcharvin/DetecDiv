function addClassification(obj,option)
% add a classification to an exisiting project

% if option is provided, a classification from the repository is imported
% or a classification is duplicated from exisiting classification in the
% shallowproject

% get the number of exisiting classification
clas=obj.processing.classification;
n=numel(clas);

if n==0
    obj.processing.classification=classi;
end

% ask user which method he wants to use

switch nargin
    case 1  % user inputs parameters of the classification
        
        disp(['Creating new classification object']);
        
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
        
        
        disp('For object classification, tracking and pedigree analysis, you need to provide 1 channel for images and 1 for (tracked) objects');
        prompt='Please enter the channel(s) on which to operate the classification ? (Default:1): ';
        channeltype= input(prompt,'s');
        if numel(channeltype)==0
            channeltype=1;
        else
            channeltype=str2num(channeltype);
        end
        
        needClasses=1;
        
        if strcmp(classlist{classitype,2},'Cell segmentation') % classes are predefined, no need to ask user
            needClasses=0;
            classes=['background cell'];
        end
        
         if strcmp(classlist{classitype,2},'Deep Image Regression') || strcmp(classlist{classitype,2},'Deep image sequence regression')  % classes are predefined, no need to ask user
            needClasses=0;
            classes='';
         end
        
        if strcmp(classlist{classitype,2},'Cell cluster lineage') | strcmp(classlist{classitype,2},'Cell cluster tracking') % for pedigree and tracking , classes are predefined
            needClasses=0;
            classes=['nolink link'];
            %classes=[];
        end
        
        if needClasses==1 % if cell segmentation, then class number is bacjground and cell by default
            prompt='Please enter the classes names that you want  (Default: class1 class2): ';
            classes= input(prompt,'s');
            
            if isempty(classes)
                % 'ok'
                classes=['class1 class2'];
            end
            
            
        end
        
        if numel(classes)~=0
            classes = textscan(classes,'%s','Delimiter',' ')';
            if numel(classes)==0
                classes={};
            end
            classes=classes{1};
            disp('Classes entered:')
            disp(classes);
        else
            classes={};
            disp('No classes were entered');
        end
        
        
        % create new classi object
        
        pth=fullfile(obj.io.path,obj.io.file);
        
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
        
        % add training data--> this was removed from this function and must
        % be done separateley
        
       % obj.processing.classification(n+1).addROI(obj,n+1);
        
    case 2

        if isstring(option)
            % in this case , either import classification from repository
            % option is a string that refers to an exisiting classification
            % object in the repository folder
            
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
            
            disp('classification available on the repository:');
            disp(idstr)
            
            ok=0;
            for i=1:size(idstr,1)
                [pt tmp ext]=fileparts(idstr{i,2});
                if strcmp(tmp,option)
                    disp('Found requested repository');
                    ok=i;
                    break
                end
            end
            
            if ok>0 % repository was found
                
                load([str idstr{ok,2}]);
                [pt tmp ext]=fileparts(idstr{ok,2});
                
                pth=[obj.io.path '/' obj.io.file];
                name=option;
                obj.processing.classification(n+1) = classi(pth,name,n+1);
                oldclassi=obj.processing.classification(n+1);
                
                %copyfile([str tmp '/' classification.strid '.mat'],[pth '/classification/' oldclassi.strid '/' oldclassi.strid '.mat']);
                copyfile([str tmp '/' classification.strid '.mat'],[pth '/classification/' oldclassi.strid '/']);
                
                obj.processing.classification(n+1)=classification;
                
                obj.processing.classification(n+1).id=oldclassi.id;
                obj.processing.classification(n+1).path=oldclassi.path;
                % obj.processing.classification(n+1).strid=oldclassi.strid;
                obj.processing.classification(n+1).roi=[]; % remove all rois associated to classification
                
                % copy classifier to directory
                
                
            else
                disp('Could not find requested repository at this location:');
                disp(str)
                disp('Quitting....');
            end
        end
        
        if isa(option,'classi')
            classitocopy=option;
            
            disp(['Duplicating classification: ' num2str(classitocopy.strid)]);
            % option is a index that refers to an exisiting classification
            
            %if option<=length(obj.processing.classification)
                
                prompt='Please enter the name of the new classification (Default: myclassi): ';
                name= input(prompt,'s');
                if numel(name)==0
                    name='myclassi';
                end
                
                pth=[obj.io.path '/' obj.io.file];
                obj.processing.classification(n+1) = classi(pth,name,n+1);

                fi=fieldnames(obj.processing.classification(n+1));
                
                for i=1:numel(fi)
                    if ~strcmp(fi{i},'path') && ~strcmp(fi{i},'strid') && ~strcmp(fi{i},'id')
                    obj.processing.classification(n+1).(fi{i})=classitocopy.(fi{i});
                    end
                end
                
                obj.processing.classification(n+1).roi=[]; % empty ROIs
                
                
                if exist([classitocopy.path '/trainingParam.mat']) % copy the training param variable to the new classif
                    disp('Found trainingParam.mat file; Copying parameters to new classification....');
                    copyfile([classitocopy.path '/trainingParam.mat'],[obj.processing.classification(n+1).path '/trainingParam.mat']);  
                end
                
                if exist([classitocopy.path '/' classitocopy.strid '.mat']) % copy the classifier variable to the new classif
                    disp('Found classifier file; Copying classifier file to new classification....');
                    copyfile([classitocopy.path '/' classitocopy.strid '.mat'],[obj.processing.classification(n+1).path '/' obj.processing.classification(n+1).strid '.mat']);  
                end
                  
                prompt=['Import ROIs from ' num2str(classitocopy.strid) ' classification [y/n] (Default: y): '];
                prevclas= input(prompt,'s');
                if numel(prevclas)==0
                    prevclas='y';
                end
 
                if strcmp(prevclas,'n')
                    return;
                end
                
                obj.processing.classification(n+1).addROI(classitocopy); % import ROis from classification option
                
                for i=1:numel(obj.processing.classification(n+1).roi) % remove irrelevant training and results data
                   obj.processing.classification(n+1).roi(i).removeData('train',classitocopy.strid);
                   obj.processing.classification(n+1).roi(i).removeData('results',classitocopy.strid);
                end
                
            else
                disp('this is not a valid classi object');
            end
        %end
end

disp(['Classification ' obj.processing.classification(n+1).strid ' has been created !']);

shallowSave(obj);

disp(['Shallow project is saved !']);





