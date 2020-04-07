classdef shallow < handle
    % class that defines the structure of an image processing project 
   properties
      % default properties with values
      io=struct('path','','file','');
      
      fov=fov({''},1,'');%fov({},1,'');
      processing=struct('roi',[],'classification',[]);%,'classification',classi());
      
      
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
           
           
           oldpath=obj.io.path;
           
           %oldpath,pathe
           
           obj.io.path=pathe;
           obj.io.file=file;
           
           % also adjust set path of dependencies 
           
           for i=1:numel(obj.fov)
               for j=1:numel(obj.fov(i).roi)
                   if numel(obj.fov(i).roi(j).path)~=0
                  % oldpath
                  % pathe
                   obj.fov(i).roi(j).path = replace(obj.fov(i).roi(j).path,oldpath,pathe);
                   end
               end
           end
           
           for i=1:numel(obj.processing.classification)
               obj.processing.classification(i).path = replace(obj.processing.classification(i).path,oldpath,pathe);
           end
           
       end
       function [path,file]= getPath(obj) % filename contains a list of path to images used in the movi project
          %  obj.props.path=pathname;
           % obj.props.name=filename;
            
           path=obj.io.path;
           file=obj.io.file;
       end
       function obj = setSrcPath(obj,path,file) % 
           % this function will be written to ensure that source image path
           % can be updated when necessary
           
           %for i=1
           StringToBeReplaced='';
           StringToReplace='';
           
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
