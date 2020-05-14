function im=readImage(obj,frame,channel)

% read specific images from sources, frames can be an array

im=[];

%aa=isfolder(obj.path)

aa=obj.srcpath{channel}

if isfolder(obj.srcpath{channel}) % folders are provided with image or based on phylocell project

list=obj.srclist{channel};
    
imstr=[fullfile(obj.srcpath{channel}, list(frame).name)];

disp(imstr)

if ~exist(imstr)
    disp('file does not exist ! Quitting....');
else
     im=imread(imstr);   
end

end



% elseif isfile(obj.pathname{channel}) % when an avi movie is loaded for instance
%             v = VideoReader(obj.pathname{channel});
%            vidHeight = v.Height;
%            vidWidth = v.Width;
%            
%            totalframes=1:v.Duration*v.FrameRate;
%            
%            if numel(frames)==0
%            frames=totalframes;
%            end
%            
%            temp=zeros(vidHeight,vidWidth,3,'uint8');
%            im=zeros(vidHeight,vidWidth,length(frames),'uint8');
%        
%            cc=1;
%             for k=1:numel(totalframes)
% 
%                if k>frames(end)
%                    continue
%                end
%                 
%                 temp=readFrame(v);
%                 
%                 if numel(find(frames==k))==0
%                    % 'ok'
%                     continue
%                 end
%                 
%                % cc
%                 if channel==obj.GFPChannel
%                 im(:,:,cc)=temp(:,:,2);
%                 end
%                 if channel==obj.PhaseChannel
%                 temp=rgb2gray(temp);
%               %  'ok'
%                 im(:,:,cc)=temp;
%                 end
%                 cc=cc+1;
%             end
% else
%    fprintf('Images can not be loaded !!! Chech path !'); 
% end

%

