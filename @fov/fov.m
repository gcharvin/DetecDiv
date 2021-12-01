classdef fov < handle
    properties
        srcpath={''}; % source directory that contains source images; may be updated each time the user loads the project
        srclist={}; % source file names 
        channel={}; %channel names when importing images
        frames=[];
        interval=[];
        binning=[];
        tag='Field of view';
        comments='';
        flaggedROIs=[];
        display=struct('intensity',1,'frame',1,'selectedchannel',1,'binning',1); % Intensity is the scaling applied for each channel
        % binning=1;
        id=''; % id string that is specific of each field of view
        %pathname={''};
        roi=roi('',[]);
        number=1;
        crop=[]; %cropping area for fov
        drift=[] %  2D vector that specifies how to translate image to suppress stage reporducibility errors
    end
    
    properties (Dependent)
        channels
    end
    
    methods
        function obj = fov(comments) % filename contains a list of path to images used in the movi project
            %obj.props.path=pathname;
            %obj.props.name=filename;
            
            if nargin==0
                % pathname={''};
               % number=1;
                comments='';
            end
            obj.comments=comments;
            
        end
        function setpathlist(obj,pathname,number,filelist,name)
            % pathname is a cell array of string with folder paths to
            % channel images
            
            % number is the fov id number
            
            % filtlist is an extra argument to subselect files associated
            % with different channels but in the same folder
            
            obj.srcpath=pathname;
            obj.number=number;
         %   [path , file ]=fileparts(pathname{1});
            
            obj.id=[name '_' num2str(number)];

            for i=1:numel(pathname)
                
%                 list=dir([obj.srcpath{i} '/*.jpg']);
%                 list=[list dir([obj.srcpath{i} '/*.tif'])];
%                 
%                 if numel(filtlist{i})
%                 clist=struct2cell(list);
%                 clist=clist(1,:);
%                 
%                 fi=true(ones(1,size(clist,2)));
%                 temp=filtlist{i};
%                 
%                 for k=1:numel(filtlist{i})
%                    
%                   if ~iscell(filtlist{i})
%                       tmp=filtlist{i};
%                   else
%                      tmp= filtlist{i}{k};
%                      
%                      if iscell(tmp)
%                          tmp=tmp{1};
%                      end
%                   end
%                   
%                 occ=regexp(clist,tmp);
%                 occ=arrayfun(@(x) numel(x{:}),occ)==1;
%                 fi = fi & occ; % filtering files repeatedly
%                 end
%                 
%                 list=list(fi);
%              %   return;
%                 end
                
                % here loop to find actual files 
                
                obj.srclist(i)=filelist(i);
            end
            

        end
        function value=get.channels(obj)
            value=numel(obj.channel);
        end
    end
end