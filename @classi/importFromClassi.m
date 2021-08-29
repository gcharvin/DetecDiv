
function importFromClassi(obj,classitocopy)

 disp(['Transferring parameters and data from classification: ' num2str(classitocopy.strid)]);
        
        fi=fieldnames(obj);
        %history_store=obj.history;
        
        for i=1:numel(fi)
            if ~strcmp(fi{i},'path') && ~strcmp(fi{i},'strid') && ~strcmp(fi{i},'id') && ~strcmp(fi{i},'roi')  && ~strcmp(fi{i},'history') 
                obj.(fi{i})=classitocopy.(fi{i});
            end
        end
        
       % obj.history=history_store;
        
        % training param
        if exist([classitocopy.path '/trainingParam.mat']) % copy the training param variable to the new classif
            
            disp(['Found  trainingParam.mat file in the original ' classitocopy.strid ' classi']);
            
            prompt=['Transfer trainingParam.mat from ' classitocopy.strid ' classification to '  obj.strid  '  [y/n] (Default: y): '];
            prevclas= input(prompt,'s');
            if numel(prevclas)==0
                prevclas='y';
            end
            if strcmp(prevclas,'y')
            copyfile([classitocopy.path '/trainingParam.mat'],[obj.path '/trainingParam.mat']);
            obj.log(['Imported training parameters from '  classitocopy.strid],'Creation')
            end
            
        end
        
        % classifier
        if exist([classitocopy.path '/' classitocopy.strid '.mat']) % copy the classifier variable to the new classif
            
             disp(['Found classifier file in the original ' classitocopy.strid ' classi']);
            
            prompt=['Transfer classifier from ' classitocopy.strid ' classification to '  obj.strid  '  [y/n] (Default: y): '];
            prevclas= input(prompt,'s');
            if numel(prevclas)==0
                prevclas='y';
            end
            if strcmp(prevclas,'y')
             copyfile([classitocopy.path '/' classitocopy.strid '.mat'],[obj.path '/' obj.strid '.mat']);
            obj.log(['Imported training parameters from '  classitocopy.strid],'Creation')
            end

        end
        
        % groundtruth data / images
        if exist([classitocopy.path, '/trainingdataset/'])
            prompt=['Transfer trainingdataset folder with exported groundtruth data from ' num2str(classitocopy.strid) ' classification [y/n] (Default: y): '];
            prevclas= input(prompt,'s');
            if numel(prevclas)==0
                prevclas='y';
            end
            if strcmp(prevclas,'y')
                mkdir(obj.path,'trainingdataset')
                copyfile([classitocopy.path '/trainingdataset/*'],[obj.path '/trainingdataset/']);
                obj.log(['Transfered trainingdatset folder from '  classitocopy.strid],'Creation')
            end
        end
        
        
        % ROIs
        prompt=['Transfer ROIs from ' num2str(classitocopy.strid) ' classification [y/n] (Default: y): '];
        prevclas= input(prompt,'s');
        if numel(prevclas)==0
            prevclas='y';
        end
        
      
        if strcmp(prevclas,'y')
            obj.addROI(classitocopy); % import ROis from classification option
            
         %   for i=1:numel(obj.roi) % remove irrelevant training and results data
         %       obj.roi(i).removeData('train',classitocopy.strid);
         %       obj.roi(i).removeData('results',classitocopy.strid);
         %   end
        end
        
   