function init(obj,option)
% initializes or set classi properties

switch nargin
    case 1  % user inputs parameters of the classification
        
        disp(['Initializing classification object...']);
        
       prompt='Set classi parameters at the command line (1) or import from repository (2) ?  (Default:1): ';
        cla= input(prompt);
        if numel(cla)==0
            cla=1;
        end
        
        switch cla
            case 2 % import from repository
             
                    disp(' ');
                    list=listRepositoryClassi;
                    disp(list)
                    
                    prompt='Please enter the number associated with the classification you wish to set from the repository ? (Default:1): ';
                    classitype= input(prompt);
                     if numel(classitype)==0
                        classitype=1;
                     end
                    
                     path=listRepositoryClassi(classitype);
                     
                    classitocopy=classiLoad(path);
                    obj.importFromClassi(classitocopy)

            case 1 % set parameters manually
                
        str=which('shallowNew.m');
        [pth file ext]=fileparts(str);
        str=[pth '/classification/classlist.mat'];
        load(str);
        disp(classlist)
        
        prompt='Please enter the number associated with the classification you wish to set ? (Default:1): ';
        classitype= input(prompt);
        if numel(classitype)==0
            classitype=1;
        end
        
        seqone=0;
        if classitype==4 | classitype==13 % LSTM classification ; enter output type ; default : sequence
            prompt='LSTM:  type of classif/reg output : sequence-to-sequence (0) or sequence-to-one (1) ? (Default:0): ';
            seqone= input(prompt);
            if numel(seqone)==0
                seqone=0;
            end
        end
        
        % for image classif/regression only
        channeltype=0;
        if classitype~=13
            disp('For object classification, tracking and pedigree analysis, you need to provide 1 channel for images and 1 for (tracked) objects');
            prompt='Please enter the channel(s) on which to operate the classification ? (Default:1): ';
            channeltype= input(prompt,'s');
            if numel(channeltype)==0
                channeltype=1;
            else
                channeltype=str2num(channeltype);
            end
        end
        
        needClasses=1;
        
        if strcmp(classlist{classitype,2},'Cell segmentation') % classes are predefined, no need to ask user
            needClasses=0;
            classes='background cell';
        end
        
        outt='';
        outp=[];
        outa={};
        
         if classitype==2 || classitype==8 % pixel classification : ask type of output 
          
             disp('');
              disp('For pixel classification, please specify what kind of output: ');
              disp('segmentation : outputs a segmented image with default thresholding in a single channel with indexed colors');
              disp('proba : outputs the proba for each class as one channel per class in a grayscale image ');
              disp('postprocessing : outputs a segmented image  in a single channel with indexed colors after custom postprocessing ');
              
            prompt='Please enter the desired output ? (Default: segmentation):';
            outt= input(prompt,'s');
            if numel(outt)==0
               outt='segmentation';
            end
            
            
            if strcmp(outt,'postprocessing')
            prompt='For postprocessing, you need to specify the function to be used (Default: @post):';
            outp= input(prompt,'s');
            if numel(outp)==0
               outp=@post;
            end
             prompt='For postprocessing, you need to specify the arguments of the function (Default: none):';
            outa= input(prompt,'s');
            if numel(outa)==0
               outa={};
            end
                
            end
             
         end
             
        
        cla=0;
        fields=[];
        
        if classitype==13 % timeseries classification/regression
            prompt='Timeseries Classification (0) or regression (1) ? (Default:0): ';
            cla= input(prompt);
            if numel(cla)==0
                cla=0;
            end
            
            if cla==1 % it s a regression problem, so no classes
                needClasses=0;
                classes='';
            end
            
            prompt='subfield of ROI to classify/regress on ? (Default:results.testlstm_3.prob): ';
            fields= input(prompt,'s');
            if numel(fields)==0
                fields='results.testlstm_3.prob';
            end
            
            if cla==1 % it s a regression problem, so no classes
                needClasses=0;
                classes='';
            end
            
        end
        
        if strcmp(classlist{classitype,2},'Deep Image Regression') || strcmp(classlist{classitype,2},'Deep image sequence regression') % classes are predefined, no need to ask user
            needClasses=0;
            classes='';
        end
        
        
        if strcmp(classlist{classitype,2},'Cell cluster lineage') | strcmp(classlist{classitype,2},'Cell cluster tracking') % for pedigree and tracking , classes are predefined
            needClasses=0;
            classes=['nolink link'];
            %classes=[];
        end
        
        if needClasses==1 % % classes are needed
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
        
        if classitype >0 && classitype<= size(classlist,1) % user chose a correct method
            
            %        obj.processing.classification(n+1) = classi(pth,name,n+1);
            
            obj.typeid=classitype;
            obj.description=[classlist{classitype,2} ' -' classlist{classitype,3}];
            obj.category=classlist{classitype,4};
            obj.classifyFun=classlist{classitype,6}{1};
            obj.trainingFun=classlist{classitype,5}{1};
            obj.channel=channeltype;
            obj.classes=classes;
            obj.output=seqone;
            obj.trainingset=fields;
            obj.colormap=shallowColormap(numel(classes));
            
            if numel(outt) % user chose pixel classification and an output type
                obj.outputType=outt; 
                
                if strcmp(outt,'postprocessing')
                 obj.outputFun=outp;
                 obj.outputArg=outa;
                end
            end
        else
            disp('Error : wrong classification type number!');
            return;
        end
        end
        
        
    case 2
        
        if ~isa(option,'classi')
            disp('The argument does not correspond to a valid @classi object: Quitting....');
            obj.log('Parameter initialization failed ','Creation')
            return
        end
        
        classitocopy=option;
        
        obj.importFromClassi(classitocopy)
end

obj.log('Parameter initialization was termnated succesfully','Creation')
disp(['Initialization was successful']);
classiSave(obj);
