classdef fov < handle
     properties
      srcpath={''}; % source directory that contains source images; may be updated each time the user loads the project
      srclist={};
      tag='Field of view';
      comments='';
      display=struct('intensity',1,'frame',1,'selectedchannel',1,'binning',1); % Intensity is the scaling applied for each channel
     % binning=1;
      id=''; % id string that is specific of each field of view
      
      roi=roi('',[]); 
     end
   
     properties (Dependent)
         channels
     end
     
   methods
       function obj = fov(pathname,number,comments) % filename contains a list of path to images used in the movi project
            %obj.props.path=pathname;
            %obj.props.name=filename;
            obj.srcpath=pathname;
            [path , file ]=fileparts(pathname{1});
            
            obj.id=[file '_' num2str(number)];
            
            for i=1:numel(pathname)
                
                list=dir([obj.srcpath{i} '/*.jpg']);
                list=[list dir([obj.srcpath{i} '/*.tif'])];
                
                obj.srclist{i}=list;
                obj.display.intensity(i)=1;
            end
            
            
            obj.comments=comments;
       end
       function value=get.channels(obj)
          value=numel(obj.srcpath); 
       end
   end
end