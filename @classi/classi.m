classdef classi < handle
    properties
        id=[] % number that identifies the classification algo
        
        typeid=1; % default category for classification found the classilist.mat file in the classification folde
        trainingset=[]; % % list of ROI ids used for training
        output=0; % type of output : 'one' , or 'sequence' for lstm classification
        path='' %  path where
        strid='';
        description='';
        category='';
        roi=roi('',[]);
        channel=1;
        classes={}; % names of the classes
        classifyFun='';
        trainingFun='';
        colormap=[];
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
                mkdir(path,'classification');
                obj.path=fullfile(path,'classification');
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
            
            oldpath=fixpath(obj.path);
            
            % oldpath(strfind(oldpath,'\'))='/';
            
            %oldpath,pathe
            
            oldfile=obj.strid;
            
            obj.path=pathe;
            obj.file=file;
            
            % also adjust set path of dependencies
            
            oldfullpath=fullfile(oldpath,oldfile);
            
            newpath=fullfile(pathe,file);
            
            
            %      obj.processing.classification(i).path=fixpath(fullfile(obj.processing.classification(i).path));
            
            
            
            
            %     obj.processing.classification(i).path = replace(obj.processing.classification(i).path,oldfullpath,newpath);
            
            
            %   bb=obj.processing.classification(i).path
            
            
            for j=1:numel(obj.roi)
                
                
                obj.roi(j).path=fixpath(fullfile(obj.roi(j).path));
                
                obj.roi(j).path = replace(obj.processing.classification(i).roi(j).path,oldfullpath,newpath);
                
            end
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
    
end
