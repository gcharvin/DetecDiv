function [im,list]=readImage(obj,frames,channel,listin)

% read specific images from sources, frames can be an array

im=[];


%aa=isfolder(obj.path)

if isfolder(obj.pathname{channel}) % folders are provided with image / based on phylocell project

if nargin==4
list=listin;
else
   % 'ok'
list=dir([obj.pathname{channel} '/*.jpg']);
list=[list dir([obj.pathname{channel} '/*.tif'])];
end

%pause(0.1);
cc=1;
for i=frames
%i,size(list),aa=list(i).name
imstr=fullfile(obj.pathname{channel}, list(i).name);

if ~exist(imstr)
    fprintf('file does not exist !');
else
    if cc==1
     im=imread(imstr);   
    else
    im(:,:,cc)=imread(imstr);
    end
    
    cc=cc+1;
end


end

elseif isfile(obj.pathname{channel}) % when an avi movie is loaded for instance
            v = VideoReader(obj.pathname{channel});
           vidHeight = v.Height;
           vidWidth = v.Width;
           
           totalframes=1:v.Duration*v.FrameRate;
           
           if numel(frames)==0
           frames=totalframes;
           end
           
           temp=zeros(vidHeight,vidWidth,3,'uint8');
           im=zeros(vidHeight,vidWidth,length(frames),'uint8');
       
           cc=1;
            for k=1:numel(totalframes)

               if k>frames(end)
                   continue
               end
                
                temp=readFrame(v);
                
                if numel(find(frames==k))==0
                   % 'ok'
                    continue
                end
                
               % cc
                if channel==obj.GFPChannel
                im(:,:,cc)=temp(:,:,2);
                end
                if channel==obj.PhaseChannel
                temp=rgb2gray(temp);
              %  'ok'
                im(:,:,cc)=temp;
                end
                cc=cc+1;
            end
else
   fprintf('Images can not be loaded !!! Chech path !'); 
end

%

