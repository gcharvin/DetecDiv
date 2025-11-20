classdef classi < handle
    properties
        id=[] % number that identifies the classification algo
        
        typeid=1; % default category for classification found the classilist.mat file in the classification folde
        trainingset=[]; % % list of ROI ids used for training
        trainingParam=[];
        output=0; % type of output : 'one' , or 'sequence' for lstm classification
        path='' %  path where
        strid=''; % string id of the classi object 
        description='';
        category='';
        roi=roi('',[]);
        channel=1;
        channelName='';
        channelName2='';
        classes={}; % names of the classes
        classifyFun='';
        trainingFun='';
        colormap=[];
        bounds= struct('Type','Auto','Rules',struct('Dataseries',{[]},'Dataset',{[]},'Value',{[]},'Occurence',[0],'Offset',[0 ])); % type can be : auto,  manual, rules;   'Rules' is a struc that specifies the type of rules : ; 'Values' specifies the automated interval set for all ROIs 
  
        score=[]; %struct('roisid',[],'recall',[],'accuracy',[],'fscore',[],'confusion',[],'classes',[],'rois',[]); %  a structure that stores the scores of the classification , which is done by the stats method
        
        % only for pixel classification
        outputType=''; % other options are : proba (outputs probabilities of class rather than segmentation), postpocressing (uses a default @post function for postprocessing), segmentation 
        outputFun=[];
        outputArg={};
        
        
        history=table('Size',[1 3],'VariableTypes',{'datetime','string','string'},'VariableNames',{'Date','Category','Message'});
        %  inputsize=[]; %size of the network (required for lstm only
    end
    methods
        function obj = classi(path,name,id)
            
            if nargin<1
                path='';
                name='';
                id=1;
            end
            
            obj.path=path;
            obj.id=id;
            
            
            obj.strid=[name '_' num2str(id)];
            obj.colormap=shallowColormap(1); % default colormap
            
            if numel(path)>0
               % mkdir(path,'classification');
              %  obj.path=fullfile(path,'classification');
                mkdir(obj.path,obj.strid);
                obj.path=fullfile(obj.path,obj.strid);
            end
        end
        
        function addTrainingData(obj,list)
            % list is provdided as a an array  FOVid // ROIs : [1 1 1 1; 1 2
            % 3 4 ]
            % HERE add training data
            
            obj.trainingset=[obj.trainingset list];
            
            % copy files and ROI objects to training folder
            
            % update GUI to include classification capabilities
        end
        function [path,file]= getPath(obj)
            %  obj.props.path=pathname;
            % obj.props.name=filename;
            
            path=obj.path;
            file=obj.strid;
        end
        function obj = setPath(obj,pathe,file)
            
        %   aa= obj.path
        
            oldpath=fixpath(obj.path);
            
            % oldpath(strfind(oldpath,'\'))='/';
            
            %oldpath,pathe
            
            oldfile=obj.strid;
            
            obj.path=pathe;
          %
          %  obj.strid=strid;
            
            % also adjust set path of dependencies
            
         %   oldfullpath=fullfile(oldpath);
            
        %    newpath=fullfile(pathe);
            
            
            
            for j=1:numel(obj.roi)
                
                 obj.roi(j).path = pathe;
           %     obj.roi(j).path=fixpath(fullfile(obj.roi(j).path));
           %     obj.roi(j).path = replace(obj.roi(j).path,oldfullpath,newpath);
      
            end
  
        
        function pathout=fixpath(pathin)
            pathout=pathin;
            if ~ispc
                
                pathout(strfind(pathout,'\'))='/';
                
            else
                
                pix=strfind(pathout,'\\');
                
                if numel(pix)
                    pathout=pathout(pix+1:end);
                end
                
                pathout(strfind(pathout,'/'))='\';
            end
        end
        
        end

    function disp(obj)
    % Custom display for classi objects

    % ===== CASE 1: ARRAY OF CLASSI =====
    if numel(obj) > 1
        nC = numel(obj);
        fprintf('classi objects (%d):\n', nC);

        % header
        fprintf('    %-4s %-22s %-12s %-6s %-s\n', ...
                'Idx', 'Name', 'Category', '#ROI', 'Path');

        for k = 1:nC
            c = obj(k);

            % Name (strid if possible)
            cName = '';
            if isprop(c,'strid') && ~isempty(c.strid)
                cName = strsafe(c.strid);
            elseif isprop(c,'id')
                cName = ['class_' strsafe(num2str(c.id))];
            else
                cName = ['classif_' num2str(k)];
            end

            % Category
            cCat = '';
            if isprop(c,'category') && ~isempty(c.category)
                cCat = strsafe(c.category);
            end

            % #ROI
            nRoiC = 0;
            if isprop(c,'roi') && ~isempty(c.roi)
                try
                    nRoiC = numel(c.roi);
                catch
                end
            end

            % Path (shortened a bit for readability)
            pth = '';
            if isprop(c,'path') && ~isempty(c.path)
                pth = strsafe(c.path);
            end

            fprintf('    %-4d %-22s %-12s %-6d %-s\n', ...
                    k, cName, cCat, nRoiC, pth);
        end

        return; % important: ne pas afficher la version détaillée après
    end

    % ===== CASE 2: SINGLE CLASSI OBJECT =====
    c = obj; % alias

    fprintf('==============================\n');
    fprintf('  Classification object\n');
    fprintf('==============================\n');

    % --- Identification
    fprintf('ID        : %s\n', num2str(c.id));

    fprintf('String ID : %s\n', strsafe(c.strid));

    catStr = strsafe(c.category);
    if ~isempty(catStr)
        fprintf('Category  : %s\n', catStr);
    end

    descStr = strsafe(c.description);
    if ~isempty(descStr)
        fprintf('Desc.     : %s\n', descStr);
    end

    fprintf('\n');

    % --- Path
    fprintf('Path      : %s\n', strsafe(c.path));
    fprintf('\n');

    % --- Type & channels
    fprintf('Type ID   : %s\n', num2str(c.typeid));

    % channel line, incl. channelName / channelName2 if available
    chanLine = sprintf('%d', c.channel);
    ch1 = strsafe(c.channelName);
    ch2 = strsafe(c.channelName2);
    if ~isempty(ch1)
        chanLine = [chanLine ' (' ch1 ')'];
    end
    if ~isempty(ch2)
        chanLine = [chanLine ' / ' ch2];
    end
    fprintf('Channel   : %s\n', chanLine);

    % --- Functions
    if ~isempty(c.classifyFun)
        fprintf('Classify fun : %s\n', fun2char(c.classifyFun));
    end
    if ~isempty(c.trainingFun)
        fprintf('Training fun : %s\n', fun2char(c.trainingFun));
    end

    fprintf('\n');

    % --- Classes
    if ~isempty(c.classes)
        classNames = c.classes;
        if isstring(classNames)
            classNames = cellstr(classNames);
        end
        if ischar(classNames)
            classNames = {classNames};
        end
        if iscell(classNames)
            flatNames = strjoin(cellfun(@strsafe, classNames, 'UniformOutput', false), ', ');
            fprintf('Classes (%d): %s\n', numel(classNames), flatNames);
        else
            fprintf('Classes : [unhandled format]\n');
        end
    else
        fprintf('Classes : none defined\n');
    end

    fprintf('\n');

    % --- Associated data
    nRoi = 0;
    if ~isempty(c.roi)
        nRoi = numel(c.roi);
    end
    nTrain = 0;
    if ~isempty(c.trainingset)
        nTrain = numel(c.trainingset);
    end

    fprintf('Associated data:\n');
    fprintf('  • %d ROI(s)\n', nRoi);
    fprintf('  • %d training sample(s)\n', nTrain);

    % --- Scores summary (optional block like before)
    if ~isempty(c.score) && isstruct(c.score)
        fieldsToShow = {'recall','accuracy','fscore'};
        f = intersect(fieldsToShow, fieldnames(c.score));
        if ~isempty(f)
            fprintf('\nScores:\n');
            for kk = 1:numel(f)
                val = c.score.(f{kk});
                if isnumeric(val)
                    m = mean(val(:), 'omitnan');
                    fprintf('  %s : %.3f\n', f{kk}, m);
                elseif iscell(val) && ~isempty(val) && isnumeric(val{1})
                    m = mean(val{1}(:), 'omitnan');
                    fprintf('  %s : %.3f\n', f{kk}, m);
                else
                    fprintf('  %s : %s\n', f{kk}, strsafe(val));
                end
            end
        end
    end

    fprintf('==============================\n');

    % ===== helpers =====
    function out = strsafe(x)
        if isempty(x)
            out = '';
        elseif ischar(x)
            out = x;
        elseif isstring(x)
            x = x(:);
            out = strjoin(cellstr(x), ', ');
        elseif iscell(x)
            try
                out = strjoin(cellfun(@strsafe, x, 'UniformOutput', false), ', ');
            catch
                out = '[cell]';
            end
        elseif isnumeric(x)
            out = num2str(x);
        else
            out = class(x);
        end
    end

    function out = fun2char(f)
        if isa(f,'function_handle')
            out = func2str(f);
        elseif ischar(f)
            out = f;
        elseif isstring(f)
            out = char(f);
        else
            out = '[unknown function spec]';
        end
    end
end





    
    end
end
