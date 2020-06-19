function [rgb fr]=export(obj,varargin)
% generates an AVI movie file from ROI


% export trap data as movie
% outputs rgb as a 4-D 8bits rgb matrix for inclusion into a bigger movie


if numel(obj.image)==0
    obj.load
end
if numel(obj.image)==0
    disp('Could not load roi image : quitting...!');
    return;
end


frames= 1:size(obj.image,4);
%channelid=1;

name=[];
framerate=10;

for i=1:numel(varargin)
    
    if strcmp(varargin{i},'Frames')
        frames=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Name')
        name=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Framerate')
        framerate=varargin{i+1};
    end
    
end


if numel(name)==0
    filename =  [obj.path '/im_' obj.id '.mp4'];
else
    filename =  [obj.path '/' name '.mp4'];
end


v=VideoWriter(filename,'MPEG-4');

v.FrameRate=framerate;
open(v);


ce=1;
reverseStr='';


% if numel(findobj('Tag',['ROI' obj.id])) % handle exists already
%     h=findobj('Tag',['ROI' obj.id]);
% else
%     h=figure('Tag',['ROI' obj.id]);%'Toolbar','none');%,'MenuBar','none');%,'Toolbar','none');
%     draw(obj,h);
% end

for frame=frames
    
    %imtemp=uint8(zeros(size(obj.gfp)));
    obj.view(frame);
     h=findobj('Tag',['ROI' obj.id]);
     
    %imtemp=permute(imtemp, [1 2 4 3]);
    fr=[];
    frame=[];
    cc=1;
    
    for j=1:numel(obj.display.selectedchannel)
        
        if obj.display.selectedchannel(j)==1
  
            hp=findobj(h,'Tag',['AxeROI' num2str(cc)]);
            axes(hp);
           % if numel(hp)~=0
                fr=getframe; % for each axe and then update
            %    figure, imshow(fr.cdata);
               % j,cc
               % return;
                
                if cc==1
                    frame.cdata=fr.cdata;
                    frame.colormap=fr.colormap;
                else
                    x=size(frame.cdata,1);
                    y=size(frame.cdata,2);
                    
                    frame.cdata(1:size(fr.cdata,1),y+1:y+size(fr.cdata,2),:)=fr.cdata;
                    
                 %   size(frame.cdata)
                end
                
                cc=cc+1;
                
             %   cc
              %  figure, imshow(frame.cdata);
             %   pause
            %end
        end
    end
    
    %return
    writeVideo(v,frame);
    
    if mod(ce-1,50)==0
%         msg = sprintf('%d / %d Frames snapped', ce , size(obj.image, 4) ); %Don't forget this semicolon
%         msg=[msg ' for trap ' obj.id];
%         
%         fprintf([reverseStr, msg]);
%         reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    ce=ce+1;
end


fprintf('\n');


close(v);


