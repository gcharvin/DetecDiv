classdef process < handle
    
    properties
        id=[] % number that identifies the classification algo
        
        typeid=1; % default category for classification found the classilist.mat file in the classification folde
        path='' %  path where
        strid=''; % string id of the classi object 
        description='';
        category='';
       
        param={};
    
        processFun='';

        processArg={};
        
        
        history=table('Size',[1 3],'VariableTypes',{'datetime','string','string'},'VariableNames',{'Date','Category','Message'});
        %  inputsize=[]; %size of the network (required for lstm only
    end
    methods
        function obj = process(path,name,id)
            
            if nargin<1
                path='';
                name='';
                id=1;
            end
            
            obj.path=path;
            obj.id=id;
            
            
            obj.strid=[name '_' num2str(id)];
         
            if numel(path)>0
               % mkdir(path,'classification');
              %  obj.path=fullfile(path,'classification');
                mkdir(obj.path,obj.strid);
                obj.path=fullfile(obj.path,obj.strid);
            end
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
            
            oldfullpath=fullfile(oldpath);
            
            newpath=fullfile(pathe);
            
            
            %      obj.processing.classification(i).path=fixpath(fullfile(obj.processing.classification(i).path));
            
            
            
            
            %     obj.processing.classification(i).path = replace(obj.processing.classification(i).path,oldfullpath,newpath);
            
            
            %   bb=obj.processing.classification(i).path
            
            
        
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
end