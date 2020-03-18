classdef movi < handle
   properties
      % default properties with values
      filename
      pathname
      path
      projectpath
      GFPChannel
      PhaseChannel
      id
      divisionTime=6; % in frame units; used to detect division peaks
      intensity=0.2; % defualt threshold for iage adjustement

      
      pattern % trap pattern for position 
      cavity =[];  % structure that contains geometrical information on cavity
      
      imsize=[]; % image size
      nframes=[]; % number of frames
      
      gfp % contains list of phc contrast images
      phc % contains list of gfp images
      trap=trap([],[],[]) % contains list of traps identified
      pixclassifier
      pixclassifierpath
      objclassifier
      objclassifierpath
      divclassifier
      divclassifierpath
      tag='movi';
   end
   methods
       function obj = movi(pathname,filename,GFPChannel,PhaseChannel) % filename contains a list of path to images used in the movi project
            obj.pathname=pathname;
            obj.filename=filename;
            
            if nargin==1
                obj.GFPChannel=2;
                obj.PhaseChannel=1;
            else
                obj.GFPChannel=GFPChannel;
                obj.PhaseChannel=PhaseChannel;
            end

        end
%        
%        function loadgfp(obj,frames)
%            
%            [pth fle ext]=fileparts(obj.gfpfilename);
%            
%            if strcmp(ext,'avi')
%            v = VideoReader(obj.gfpfilename);
%            vidHeight = v.Height;
%            vidWidth = v.Width;
%            
%            if nargin==1
%               frames=1:v.Duration*v.FrameRate;
%            end
%            
%            temp=zeros(vidHeight,vidWidth,3,'uint8');
%            
%            obj.gfp=zeros(vidHeight,vidWidth,length(frames),'uint8');
%        
%             k = 1;
%             
%             for k=frames
%                 temp=readFrame(v);
%                 obj.gfp(:,:,k)=temp(:,:,2);
%             end
%             
%            else
%              frames=1:11;
%              tmp=imread('001_gfp.tiff');
%              obj.gfp=zeros(size(tmp,1),size(tmp,2),length(frames),'uint16');
%              
%                for k=frames
%                    
%                    str=num2str(k);
%                    while numel(str)<3
%                        str=['0' str];
%                    end
%                    
%                    obj.gfp(:,:,k)=imread([str '_gfp.tiff']);
%                end
%            end
%                
%        end
       
%        function loadphc(obj,frames)
%            
%             [pth fle ext]=fileparts(obj.phcfilename);
%            
%            if strcmp(ext,'avi')
%            v = VideoReader(obj.phcfilename);
%            vidHeight = v.Height;
%            vidWidth = v.Width;
%            
%            if nargin==1
%               frames=1:v.Duration*v.FrameRate;
%            end
%            
%            temp=zeros(vidHeight,vidWidth,1,'uint8');
%            
%            obj.phc=zeros(vidHeight,vidWidth,length(frames),'uint8');
%        
%             k = 1;
%             
%             for k=frames
%                 temp=rgb2gray(readFrame(v));
%                 obj.phc(:,:,k)=temp;
%             end
%            else
%                frames=1:11;
%              tmp=imread('001_ph.tiff');
%              obj.phc=zeros(size(tmp,1),size(tmp,2),length(frames),'uint16');
%              
%                for k=frames
%                    
%                    str=num2str(k);
%                    while numel(str)<3
%                        str=['0' str];
%                    end
%                    
%                    obj.phc(:,:,k)=imread([str '_ph.tiff']);
%                end 
%            end
%        end
       
%        function save(obj)
%            [pth fle ext]=fileparts(obj.gfpfilename);
%            
%            str=inputname(1);
%            
%            save([fle '.mat'],str);
%        end
       
       
%       function r = roundOff(obj)
%          r = round([obj.Value],2);
%       end
%       function r = multiplyBy(obj,n)
%          r = [obj.Value] * n;
%       end
   end
end