function [rgb fr]=export(obj,varargin)
% export trap data as movie

% option : single movie with rich data : division times, fluo values etc...

% outputs rgb as a 4-D 8bits rgb matrix for inclusion into a bigger movie

frames= 1:size(obj.gfp, 3);

siz=100; % defaut movie size (sqaure)

for i=1:numel(varargin)
    
    if strcmp(varargin{i},'fluo')
        
    end

    if strcmp(varargin{i},'frames')
        frames=varargin{i+1};
    end
    
     if strcmp(varargin{i},'size')
         siz=varargin{i+1};
     end
end

if numel(obj.gfp)==0
    obj.load;
end


v=VideoWriter([obj.path '/' obj.id '.mp4'],'MPEG-4');

v.FrameRate=30;
open(v);


meangfp=[];
maxgfp=[];

for i=1:size(obj.gfp,4) % loop on all channels to calculate mean fluo values
    
    totgfp=double(obj.gfp(:,:,:,i));
    meangfp(i)=0.8*double(mean(totgfp(:)));
    
    scale=0.3;
    
    if i==obj.gfpchannel
        scale=obj.intensity;
    end
    
    if i==obj.phasechannel
        scale=0.7;
    end
    
    maxgfp(i)=double(meangfp(i)+scale*(max(totgfp(:))-meangfp(i)));
    
end

rgb=uint8(zeros(size(obj.gfp,1),size(obj.gfp,2),3,size(obj.gfp,3)));


h=figure('Position',[100 100 siz siz],'Color','w'); 
axis equal square
ce=1;
reverseStr='';


for frame=frames
    
    %imtemp=uint8(zeros(size(obj.gfp)));
    
    %imtemp=permute(imtemp, [1 2 4 3]);
    
    [B,L] = bwboundaries(obj.track(:,:,frame),'noholes'); % contours of nucleus
    
    
    for k=1:size(obj.gfp,4)
        
        temp=obj.gfp(:,:,frame,k);
        
        temp=uint8(imadjust(temp,[meangfp(k)/65535 maxgfp(k)/65535],[0 1])/256);

        if k==obj.phasechannel
            rgb(:,:,:,frame)=imadd(rgb(:,:,:,frame),cat(3,temp,temp,temp));
        elseif k==obj.gfpchannel
            rgb(:,:,obj.gfpchannel,frame)=imadd(rgb(:,:,obj.gfpchannel,frame),temp);
        else
            rgb(:,:,3,frame)=imadd(rgb(:,:,3,frame),temp);
        end
    end
    
    % display frame
     if frame==1
        im=imshow(rgb(:,:,:,frame)); 
        t=text(5,5,[num2str(10*frame) 'min'],'Color','w','FontSize',10*siz/100);
        
        %ide=regexprep(obj.id,'_','-');
        t2=text(30,5,obj.id,'Color','w','FontSize',10*siz/100,'Interpreter','none');
        
        d=text(20,10,'','Color','r','FontSize',10*siz/100);
        
        if numel(B)
        B=B{1};
        xb=B(:,2); yb=B(:,1);
        else
        xb=-[10 ; 20 ; 5]; yb=-[10 ; 0 ; 20];    
        end
        
        ver = [xb yb];
        fac = 1:numel(xb);
        
        l=patch('Faces',fac,'Vertices',ver,'FaceColor',[1 0 0],'FaceAlpha',0.3,'EdgeColor',[1 0 0],'LineWidth',2*siz/100);
       % l=patch(xb,yb);%,'FaceColor',[1 0 0],'FaceAlpha',0.3);

        h.Position=[100 100 siz siz];
        a=gca;
        a.Position=[0.05 0.05 0.9 0.9];
       % return;
     else
        im.CData=rgb(:,:,:,frame);
        
        
        if numel(B)
        B=B{1};
        xb=B(:,2); yb=B(:,1);
        else
        xb=-[10 ; 20 ; 5]; yb=-[10 ; 0 ; 20];   
        end
        
        l.XData=xb;
        l.YData=yb;
        
        %aa=l.XData
        
        t.String=[num2str(10*frame) 'min'];
     end
     
     if numel(find(find(obj.div.classi)==frame))

         d.String='Division';
     else
         d.String='';
     end
    
     fr(frame)=getframe;
     
     writeVideo(v,fr(frame));
     
      if mod(ce-1,50)==0
     msg = sprintf('%d / %d Frames snapped', ce , size(obj.gfp, 3) ); %Don't forget this semicolon
     msg=[msg ' for trap ' obj.id];
     
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
        ce=ce+1;  
end
  
fprintf('\n');
close;

close(v);
        
        
