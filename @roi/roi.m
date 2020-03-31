classdef roi < handle
   properties
      % default properties with values
      id='';
      value %
      %gfp % list of grayscale images that contain gfp data (m x n x time x channel)
      %gfpchannel
      %phasechannel
      path
      %intensity=0.2; % intensity of fluoresecence displayed on view gui
      %brushSize=3;
      %phc % list of grayscale images that contain ph data
      
      image=[]; % . images for field of view
      channelid=1;
     % imagestr={}; % contains the description for each image
      proc=[]; % sturct that contains all possible prcessing data
      
      parent=[] % reference of the parent field of view
      
      display=struct('intensity',[1 1 1],'frame',1,'selectedchannel',1,'binning',1,'rgb',[1 1 1],'channel',{'Channel 1'});
      
      classes={};
      train=[] ; %1D array that has the size of the 4rd dim of the image array and contains assigned classes; is defined when ROI is assigned to classification 
      
      results=[]; %display results if based on classification-> an array that has the same size as the number of frames
      
      % displays a list of channels in RGB channels 
      %train=[] % list of rgb images that contain pixel training data
      %classi=[] % list of rgb images that contain pixel classification RGB image , only second channel is useful
      %traintrack=[]; % list of grayscale images that contains training for nucleus tracking results
      %track=[] % array that contains 1) the nucleus index to be tracked (classification result) : 0 if no tracking 2) other information related to tracking : division etc...
      
      %cavity=[]; % geometrical information avout cavity 
      %area=[]; % area of nucleus in trajectory NOT USED
      %param=[]; % predictors used ? NOT USED
      
      %data=struct('fluo',[],'area',[]);
      %data.fluo=[]; % quantification of total fluorescence in mother nucleus
      
      %rls=[];
      
      %div=struct('reject',[],'raw',[],'classi',[],'tree',[],'dead',[],'daughter',[],'stop',[]) % structure that contains all relevant info about division, including training and classification
      
      %frame=1; %current frame being displayed;
      %pixtree % pix classifier
      %objtree % object trajectory classifier 
   end
   methods
       function obj = roi(id,roiarr)
           %%%% here
            obj.id=id;
            obj.value=roiarr;
          %  obj.gfp=gfp;
            %obj.phc=phc;
            
            %obj.classi=uint8(zeros(size(gfp,1),size(gfp,2),3,size(gfp,3)));
            %obj.train= uint8(zeros(size(gfp,1),size(gfp,2),3,size(gfp,3)));
            %obj.traintrack= uint8(zeros(size(gfp,1),size(gfp,2),3,size(gfp,3)));
            %obj.track= uint8(zeros(size(gfp,1),size(gfp,2),size(gfp,3)));
       end
       
%        function cleartraining(obj,str)
%            
%            if strcmp(str,'pix')
%                
%                
%            if numel(obj.gfp)==0
%               obj.load;
%            end
% 
%            obj.classi=uint8(zeros(size(obj.gfp,1),size(obj.gfp,2),3,size(obj.gfp,3)));
%            obj.train= uint8(zeros(size(obj.gfp,1),size(obj.gfp,2),3,size(obj.gfp,3)));
%            obj.traintrack= uint8(zeros(size(obj.gfp,1),size(obj.gfp,2),3,size(obj.gfp,3)));
%            obj.track= uint8(zeros(size(obj.gfp,1),size(obj.gfp,2),size(obj.gfp,3)));
%            
%            %obj.train=[]; % list of rgb images that contain pixel training data
%            %obj.classi=[]; % list of rgb images that contain pixel classification RGB image , only second channel is useful
%            %obj.traintrack=[]; % list of grayscale images that contains training for nucleus tracking results
%            %obj.track=[]; % array that contains 1) the nucleus index to be tracked (classification result) : 0 if no tracking 2) other information related to tracking : division etc...
%       
%       
%            %obj.close;
%            %obj.view;
%            end
%            
%            if strcmp(str,'div')
%            obj.div.reject=double(zeros(1,numel(obj.div.reject)));
%            obj.div.classi=logical(zeros(1,numel(obj.div.reject)));
%            obj.div.dead=logical(zeros(1,numel(obj.div.reject)));
%          % 'ok'
%            end
%        end
       
%        function close(obj)
%            h=findobj('Tag',['Trap' num2str(obj.id)]);
%            
%            if numel(h)~=0
%                delete(h)
%                
%            end
%        end
       

%       function r = roundOff(obj)
%          r = round([obj.Value],2);
%       end
%       function r = multiplyBy(obj,n)
%          r = [obj.Value] * n;
%       end
   end
end
