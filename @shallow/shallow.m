classdef shallow < handle
    % class that defines the structure of an image processing project
    properties
        % default properties with values
        io=struct('path','','file','');
        
        fov=fov();%fov({},1,'');
        processing=struct('roi',[],'classification',[],'processor',[]);%,'classification',classi());
        
        
        %processing.roi.pattern=[];
        
        %pattern=[];
        %       filename
        %       pathname
        %       path
        %       projectpath
        %       GFPChannel
        %       PhaseChannel
        %       id
        %       divisionTime=6; % in frame units; used to detect division peaks
        %       intensity=0.2; % defualt threshold for iage adjustement
        %
        %
        %       pattern % trap pattern for position
        %       cavity =[];  % structure that contains geometrical information on cavity
        %
        %       imsize=[]; % image size
        %       nframes=[]; % number of frames
        %
        %       gfp % contains list of phc contrast images
        %       phc % contains list of gfp images
        %       trap=trap([],[],[]) % contains list of traps identified
        %       pixclassifier
        %       pixclassifierpath
        %       objclassifier
        %       objclassifierpath
        %       divclassifier
        %       divclassifierpath
        
        tag='shallow project';
        
    end
    
    methods
        function obj = shallow(pathname,filename) % filename contains a list of path to images used in the movi project
            %  obj.props.path=pathname;
            % obj.props.name=filename;
            
            
        end
        function obj = setPath(obj,pathe,file) % filename contains a list of path to images used in the movi project
            %  obj.props.path=pathname;
            % obj.props.name=filename;
            
            
   
            oldpath=fixpath(obj.io.path);
            
           % oldpath(strfind(oldpath,'\'))='/';
            
            %oldpath,pathe
            
            oldfile=obj.io.file;
            
            obj.io.path=pathe;
            obj.io.file=file;
            
            % also adjust set path of dependencies
            
            oldfullpath=fullfile(oldpath,oldfile);
            
            newpath=fullfile(pathe,file);
            
            
%             if ispc
%                 oldfullpath=replace(oldfullpath,'/','\');
%                 newpath=replace(newpath,'/','\');
%             else
%                 oldfullpath=replace(oldfullpath,'\','/');
%                 newpath=replace(newpath,'\','/');
%             end
            
            
            
            for i=1:numel(obj.fov)
                for j=1:numel(obj.fov(i).roi)
                    if numel(obj.fov(i).roi(j).path)~=0
                        % oldpath
                        % pathe
                        
                        
                        obj.fov(i).roi(j).path=fixpath(fullfile(obj.fov(i).roi(j).path));
                        
%                         if ispc
%                             obj.fov(i).roi(j).path = replace(obj.fov(i).roi(j).path,'/','\');
%                         else
%                             obj.fov(i).roi(j).path = replace(obj.fov(i).roi(j).path,'\','/');
%                         end
                        
                        %    aa=obj.fov(i).roi(j).path
                        %       oldfullpath
                        % newpath
                        
                        obj.fov(i).roi(j).path = replace(obj.fov(i).roi(j).path,oldfullpath,newpath);
                        
%                         if ispc
%                             obj.fov(i).roi(j).path = replace(obj.fov(i).roi(j).path,'/','\');
%                         else
%                             obj.fov(i).roi(j).path = replace(obj.fov(i).roi(j).path,'\','/');
%                         end

                    end
                end
            end
            
            for i=1:numel(obj.processing.classification)
                
              %  aa=obj.processing.classification(i).path;
     

                
                obj.processing.classification(i).path=fixpath(fullfile(obj.processing.classification(i).path));
                
            %    bb=obj.processing.classification(i).path;
                
            %    obj.processing.classification(i).path(
%                 if ispc
%                     obj.processing.classification(i).path= replace( obj.processing.classification(i).path,'/','\');
%                 else
%                     obj.processing.classification(i).path = replace( obj.processing.classification(i).path,'\','/');
%                 end
                
                
                obj.processing.classification(i).path = replace(obj.processing.classification(i).path,oldfullpath,newpath);
                
                
             %   bb=obj.processing.classification(i).path
          
                
                for j=1:numel(obj.processing.classification(i).roi)
                    
                    
                    obj.processing.classification(i).roi(j).path=fixpath(fullfile(obj.processing.classification(i).roi(j).path));
                    
                    
%                     if ispc
%                         obj.processing.classification(i).roi(j).path = replace( obj.processing.classification(i).roi(j).path,'/','\');
%                     else
%                         obj.processing.classification(i).roi(j).path = replace( obj.processing.classification(i).roi(j).path,'\','/');
%                     end
                    
                    
                    obj.processing.classification(i).roi(j).path = replace(obj.processing.classification(i).roi(j).path,oldfullpath,newpath);
                    
%                     if ispc
%                         obj.processing.classification(i).roi(j).path = replace(obj.processing.classification(i).roi(j).path,'/','\');
%                     else
%                         obj.processing.classification(i).roi(j).path = replace(obj.processing.classification(i).roi(j).path,'\','/');
%                     end
                    
                end
            end
            
             for i=1:numel(obj.processing.processor)
                obj.processing.processor(i).path=fixpath(fullfile(obj.processing.processor(i).path));
                obj.processing.processor(i).path = replace(obj.processing.processor(i).path,oldfullpath,newpath);
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
        function [path,file]= getPath(obj) % filename contains a list of path to images used in the movi project
            %  obj.props.path=pathname;
            % obj.props.name=filename;
            
            path=obj.io.path;
            file=obj.io.file;
        end
        
        function obj = setSrcPath(obj,option) %
            % this function will be written to ensure that source image path
            % can be updated when necessary
            % display current path for first channel of each FOV
            
            % option : path is changed at the command line. Default : GUI
            % change
            % HERE
            
            if numel(obj.fov(1).srcpath{1})~=0 % srce path has been set for at leats one FOV; update ?
                
                for i=1:numel(obj.fov)
                    disp(['Path for FOV: ' num2str(i)])
                    disp([obj.fov(i).srcpath{1}]);
                end
            else
                disp('there is no path for FOVs; Quitting !');
                return
            end
            
            
            %for i=1
            strpath=pwd;
            
%             prompt='Reassign FOV path all at once? [y/n] (Default: y)';
%             defaultclass= input(prompt,'s');
%             if numel(defaultclass)==0
%                 defaultclass='y';
%             end
            
         %   if strcmp(defaultclass,'y') % path is changed automatically for all FOVs
         
%                 prompt='Use GUI to change path [y/n] (Default: n)';
%                 guipath= input(prompt,'s');
%                 if numel(defaultclass)==0
%                     guipath='n';
%                 end
                
                if nargin==1 % path is changed using GUI
                    for i=1:numel(obj.fov)
                        for k=1:numel(obj.fov(i).srcpath)
                            if i==1 && k==1
                                
                                prompt = {obj.fov(i).srcpath{k}};
                                dlgtitle = 'Please enter the correct path for this directory (ignore / versus \):';
                                dims = [1 150];
                                definput = {obj.fov(i).srcpath{k}};
                                answer = inputdlg(prompt,dlgtitle,dims,definput);

                                if numel(answer)==0
                                    return;
                                end
                                
                                oldpath=obj.fov(i).srcpath{k};
                                % identidy part of the path to be changed: 
                                str='';
                                for n=1:numel(oldpath)
                                    str=oldpath(end-n:end);
                                    if numel(strfind(answer{1},str))==0
                                        break
                                    end
                                end
                                
                                yo=oldpath(end-n+1:end);
                                oldbase= oldpath(1:end-n);
                                newbase=split(answer{1},yo);
                                newbase=newbase{1};
                                
                             %   strpath=uigetdir(strpath,'Input the base folder');
                                
                              %  if strpath==0
                              %      return;
                              %  end
                                
%                                 if ispc
%                                     p=strfind(strpath,'\');
%                                 else
%                                     p=strfind(strpath,'/') ;
%                                 end
                             %   basepath=strpath(1:p(end-1)-1);
                                
                            end
                            
                            tmp=obj.fov(i).srcpath{k};
                            sp=split(tmp,oldbase);
                            kep=sp{2};
                            
                       %    if ispc
                       %        p=strfind(tmp,'\');
                       %    else
                      %          p=strfind(tmp,'/');
                      %     end
                            
                       %     p
                      %      tmp=tmp(p(end-1):end);
                            
                       %     finalpath=[basepath tmp];
                            
                               finalpath=fullfile([newbase kep]);
                             %  return
                            
                            if isfolder(finalpath)
                                obj.fov(i).srcpath{k}=finalpath;
                                
                           %     obj.fov(i).srcpath{k}
                           %    if ispc
                           %        obj.fov(i).srcpath{k} = replace(obj.fov(i).srcpath{k},'/','\');
                          %     else
                           %        obj.fov(i).srcpath{k} = replace(obj.fov(i).srcpath{k},'\','/');
                           %    end
                                
                            else
                                disp('Warning : this path does not exsit: cannot change it !');
                            end
                        end
                    end
                else % path is changes as the command line
                    disp('Current source path for the FOV:')
                    disp(obj.fov(1).srcpath{1})
                    prompt='Type the part of the path to be changed:';
                    oldpath= input(prompt,'s');
                    if numel(oldpath)==0
                        return;
                    end
                    prompt='Type the new base path:';
                    newpath= input(prompt,'s');
                    if numel(newpath)==0
                        return;
                    end
                    
                    for i=1:numel(obj.fov)
                        for k=1:numel(obj.fov(i).srcpath)
                            tmp=obj.fov(i).srcpath{k};
                            finalpath=replace(tmp,oldpath,newpath);
                            
                            % if isfolder(finalpath)
                            obj.fov(i).srcpath{k}=finalpath;
                            
                            if ispc
                                obj.fov(i).srcpath{k} = replace(obj.fov(i).srcpath{k},'/','\');
                            else
                                obj.fov(i).srcpath{k} = replace(obj.fov(i).srcpath{k},'\','/');
                            end
                            
                            %       else
                            %           disp('Warning : this path does not exsit: cannot change it !');
                            % end
                        end
                    end
                    disp('Base path of FOVs succesfully changed! ');
                end
                
%             else % path is changed manually for all FOVs / each channel
%                 
%                 prompt='Use GUI to change path [y/n] (Default: n)';
%                 guipath= input(prompt,'s');
%                 if numel(defaultclass)==0
%                     guipath='n';
%                 end
%                 
%                 if strcmp(guipath,'y') % path is changed using GUI
%                     for i=1:numel(obj.fov)
%                         for k=1:numel(obj.fov(i).srcpath)
%                             strpath=uigetdir(strpath);
%                             obj.fov(i).srcpath{k}=strpath;
%                             
%                             if ispc
%                                 obj.fov(i).srcpath{k} = replace(obj.fov(i).srcpath{k},'/','\');
%                             else
%                                 obj.fov(i).srcpath{k} = replace(obj.fov(i).srcpath{k},'\','/');
%                             end
%                         end
%                     end
%                 else % path is changes at the command line 
%                     for i=1:numel(obj.fov)
%                         
%                         disp(['Path for FOV: ' num2str(i)])
%                         disp(obj.fov(i).srcpath{1})
%                     prompt='Type the part of the path to be changed:';
%                     oldpath= input(prompt,'s');
%                     if numel(oldpath)==0
%                         return;
%                     end
%                     prompt='Type the new base path:';
%                     newpath= input(prompt,'s');
%                     if numel(newpath)==0
%                         return;
%                     end
%                     
%                     for k=1:numel(obj.fov(i).srcpath)
%                             tmp=obj.fov(i).srcpath{k};
%                             finalpath=replace(tmp,oldpath,newpath);
%                             
%                             % if isfolder(finalpath)
%                             obj.fov(i).srcpath{k}=finalpath;
%                             
%                             if ispc
%                                 obj.fov(i).srcpath{k} = replace(obj.fov(i).srcpath{k},'/','\');
%                             else
%                                 obj.fov(i).srcpath{k} = replace(obj.fov(i).srcpath{k},'\','/');
%                             end
%                             
%                             %       else
%                             %           disp('Warning : this path does not exsit: cannot change it !');
%                             % end
%                     end
%                         
%                     end
%                 end
           % end
            
            % displays new path and check integrity by loading images
            
            if numel(obj.fov(1).srcpath{1})~=0 % srce path has been set for at leats one FOV; update ?
                
%                 for i=1:numel(obj.fov)
%                     disp(['Path for FOV: ' num2str(i)])
%                     disp([obj.fov(i).srcpath{1}]);
%                     
%                     disp('Loading first image to check path integrity....');
%                     
%                     im=obj.fov(i).readImage(1,1);
%                     
%                     if numel(im)>0
%                         disp('Path is OK for this FOV');
%                         disp('-------------------------');
%                     end
%                 end
                
                
            else
                disp('there is no path for FOVs; Quitting !');
                return
            end
            
            
            % updates each FOV or all FOVs at once
            
            
            % make a loop on all FOV objects to adjust the path for these
            % sources objects
            
            %  obj.props.path=pathname;
            % obj.props.name=filename;
            
            %obj.io.path=path;
            %obj.io.file=file;
        end
    end
end
