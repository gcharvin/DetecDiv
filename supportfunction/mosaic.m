function mosaic(obj,varargin)
% generates a rois movie with multiple cavities and rich features

% obj is the reference object: it can be either a @shallow, a @classi, or a
% @ROI.
% otyher arguments are expained below


name=[];
ips=10;
framerate=5;
channel=1;
fontsize=15;
levels=[];
training=[];
results=[];
title=[];
strid='';
roititle=0;
rls=0;
Flip=0;
rgb={};

if isa(obj,'classi')
    frames=1:size(obj.roi(1).image,4); % take the number of frames from the image list
    strid=obj.strid;
     rois=[1 2 3];
end
if isa(obj,'shallow')
    frames=1:numel(obj.fov(1).srclist{1}); % take the number of frames from the image list
    rois=[1 1 1; 1 2 3];
end
if isa(obj,'roi')
    frames=1:size(obj.image,4); % take the number of frames from the image list
end



for i=1:numel(varargin)
    
    if strcmp(varargin{i},'Frames')  frames=varargin{i+1};  end
    if strcmp(varargin{i},'Name')    name=varargin{i+1}; end
    
    if strcmp(varargin{i},'IPS') % number of frames displayed per second
        ips=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Framerate') % used to diplay the time on the movie
        framerate=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Flip') % used to diplay the time on the movie
        Flip=1;
    end
    
    if strcmp(varargin{i},'Channel') % an array that indicates the channels being displayed, can be scalar array or strid; Multiple channels will be overlaid on the same image 
        channel=varargin{i+1};
        
      
      if numel(channel)==0
          disp('Channel is not found; quitting !');
          return;
      end
    end
    
    if strcmp(varargin{i},'Levels') % defines output levels for display; must be a 2D vector [low high] for 1D channels (glike a grayscale image) , and a colormap for indexed channels:  jet(16): 
        % if several channels are to be overlaid, then a cell array of
        % string must be used : { [low high] , jet(16)}
        
        levels=varargin{i+1};
    end
    
      if strcmp(varargin{i},'RGB') % defines the RGB levels for each channel / cell array of 3D vectors
        
       rgb=varargin{i+1};
      end
    
    
    if strcmp(varargin{i},'FontSize')
        fontsize=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Mosaic') % draws the contour of ROIs on the movie
        rois=varargin{i+1};
        
    end
    
    if strcmp(varargin{i},'Training') % displays the training data (ground truth)
        training=1; %varargin{i+1};
    end
    
    if strcmp(varargin{i},'Results') %displays the classi results
        results=1;%varargin{i+1};
    end
    
    if strcmp(varargin{i},'Classification') % enters the strid of the classif to be included
        strid=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Title') % display title information on top of the movie
        title=varargin{i+1};
    end
    
    if strcmp(varargin{i},'ROITitle') % display title for each roi
        roititle=1;
    end
    
    if strcmp(varargin{i},'RLS') %
        rls=1;
    end
    
end

if numel(levels)==0
    disp('Display levels were not provided ! Will assume that all the channels are grayscale images and will normalize levels'); 
end


% rois mode: displays specific ROIs from different FOVs
% find number of lines and columns
if isa(obj,'roi')
    rois=[];
end

if isa(obj,'roi') |  isa(obj,'shallow')
    if numel(training) | numel(results)
        if numel(strid)==0
            disp('You need to provide the strid of the classification training/resultss to be displayed; Quitting ! ');
            return;
        end
    end
end


if numel(rois)
    nmov=size(rois,2);
    nsize=[1 1; 1 2; 1 3; 2 2; 2 3; 2 3; 3 3; 3 3; 3 3];
    if nmov>9
        nsize=floor(sqrt(nmov-1))+1;
        nsize=[nsize nsize];
    else
        nsize=nsize(nmov,:);
    end
    
  
else
    nsize=[1 1];
    nmov=1;
end

% load template image to check image size
if isa(obj,'classi')
    img=obj.roi(rois(1)).image;
    if numel(img)==0
        obj.roi(rois(1)).load;
    end
    roitmp=obj.roi(rois(1));
end

if isa(obj,'shallow')
    img=obj.fov(rois(1,1)).roi(rois(2,1)).image;
    if numel(img)==0
        obj.fov(rois(1,1)).roi(rois(2,1)).load;
    end
    roitmp=obj.fov(rois(1,1)).roi(rois(2,1));

end

if isa(obj,'roi')
    img=obj.image;
    if numel(img)==0
        obj.load;
    end
     roitmp=obj;
end

   nframesref=size(roitmp.image,4);

% find the right channel 
cha={};

if numel( rgb)==0
    rgb=cell(numel(channel),1);
end

if numel(levels)==0
    levels=cell(numel(channel),1);
end


for i=1:numel(channel)
    if iscell(channel)
         cha{i}=roitmp.findChannelID(channel{i});   
      else
         pix=find(roitmp.channelid==channel(i));
        cha{i}=pix;
    end
  
    if numel(rgb{i})==0
        rgb{i}=[1 1 1];
    end
    
    if numel(levels{i})==0
        levels{i}=[0 1];
    end
        
end

  
% set up extra display pixels
% columns on the left of the movie

shiftx=0;
if numel(training)
    shiftx=10;
end
if numel(results)
    shiftx=shiftx+10;
end

% add row for roi title
shifty=0;
if roititle>0 | rls>0
    shifty=16;
end

h=size(img,1)+shifty;
w=size(img,2)+shiftx;
imgout=zeros(nsize(1)*h,nsize(2)*w,3,numel(frames));
cc=1;

%   if numel(channel)==1
%                pix=find(roitmp.channelid==channel);
%                if numel(pix)>1 % multichannel
%                    channel=pix;
%                end
%   end
        

  
for k=1:nsize(1) % include all requested rois
    for j=1:nsize(2)
        
        if isa(obj,'classi')
            roitmp=obj.roi(rois(cc));
        end
        
        if isa(obj,'shallow')
            roitmp=obj.fov(rois(1,cc)).roi(rois(2,cc));
        end
        
        if isa(obj,'roi')
            roitmp=obj;
        end
        
        if numel(roitmp.image)==0
        roitmp.load;
        end
        
         disp(['ROI ' roitmp.id ' loaded']);
         
         if numel(intersect(1:size(roitmp.image,4) , frames)) < numel(frames)
             disp('this ROI does not have enough frames, you must provide a compatible frames argument');
         end
                
        imtmp=roitmp.image(:,:,:,frames);
        
       
        
     %   imblack=uint16(zeros(size(imtmp,1),shiftx,size(imtmp,3),size(imtmp,4)));
     %   imout=cat(2,imblack,imtmp);
        
     %   imblack2=uint16(zeros(shifty,size(imout,2),size(imout,3),size(imout,4)));
     %   imout=cat(1,imblack2,imout);
        
%         imout= uint16(zeros(size(imtmp,1),size(imtmp,2),3,size(imtmp,4)));
%         
%         imblack=uint16(zeros(size(imtmp,1),shiftx,3,size(imtmp,4)));
%         imout=cat(2,imblack,imtmp);
%         
%         imblack2=uint16(zeros(shifty,size(imout,2),3,size(imout,4)));
%         imout=cat(1,imblack2,imout);
        
        imout=uint16(zeros(size(imtmp,1),size(imtmp,2),3,size(imtmp,4)));
        
        for i=1:size(imtmp,4) % loop on frames
          
           imgRGBsum=uint16(zeros(size(imtmp,1),size(imtmp,2),3));
           
           for ii=1:numel(cha)
               
           
           imtmp2=imtmp(:,:,cha{ii},i);
           
           
           if numel(cha{ii})==1 % single dimension channel => levels can be readjusted 
             
             
               
           if numel(levels{ii})==2 % A 2D vector is provided, therefore image is not an indexed one
               imtmp2 = imadjust(imtmp2,[levels{ii}(1)/65535 levels{ii}(2)/65535],[0 1]);
               imtmp2= cat(3, imtmp2*rgb{ii}(1), imtmp2*rgb{ii}(2), imtmp2*rgb{ii}(3)); 
           else % channel represents an indexed image , will use provided colormap 
               maxe= max( imtmp2(:));
               
               imrgbbw=uint16(zeros(size(imgRGBsum)));
               
               for iii=1:maxe
                   bw=65535*uint16(imtmp2==iii);
                   imrgb=cat(3,bw*levels{ii}(iii,1)*rgb{ii}(1),bw*levels{ii}(iii,2)*rgb{ii}(2),bw*levels{ii}(iii,3)*rgb{ii}(3));
                   imrgbbw=imlincomb(1,imrgbbw,1,imrgb);
               end
               
               imtmp2=imrgbbw;
           
           end
           end
           
            if numel(cha{ii})==3 % already a combined image ; no RGB adjustmeent is possible
                
            end
           
           
           
           if Flip==1 % flip image upside down
               imtmp2=flip(imtmp2,1);
           end
              
           imgRGBsum=imlincomb(1,imgRGBsum,1,imtmp2);  
           end
           
           imout(:,:,:,i)=imgRGBsum;
           
         %  figure, imshow(imgRGBsum,[])
         %  pause
        end
            
            
         %   if numel(channel)==1 & numel(levels)>0
        %    imout(:,:,1,i)=imadjust(imout(:,:,1,i),[levels(1)/65535 levels(2)/65535],[0 1]);
       %     t=imout(:,:,1,:);
       %     max(t(:))
%             end
%             if Flip==1
%                 I=imout(:,:,:,i);
%                 imout(:,:,:,i)=flip(I,1);
%             end
      %     end
        
      %  end
        
        
        % imout= uint16(zeros(size(imtmp,1),size(imtmp,2),3,size(imtmp,4)));
         imblack=uint16(zeros(size(imtmp,1),shiftx,3,size(imtmp,4)));
         imout=cat(2,imblack,imout);         
         imblack2=uint16(zeros(shifty,size(imout,2),3,size(imout,4)));
         imout=cat(1,imblack2,imout);
        
        % add black frame around ROIs
        framesize=2;
        imout(1:framesize,:,:,:)=0;
        imout(end-framesize+1:end,:,:,:)=0;
        imout(:,1:framesize,:,:)=0;
        imout(:,end-framesize+1:end,:,:)=0;
        
%         if numel(channel)==1
%             imout=repmat(imout,[1 1 3 1]);
%         end
        
        %imout(:,:,2,:)=imout(:,:,1,:);
        %imout(:,:,3,:)=imout(:,:,1,:);
        

        % insert features here
        % calculate RLS  based on measureRLS2
        if rls==1
            [rlsout,rlsresults,rlstraining]=measureRLS2(obj,strid,'bud','Rois',rois(cc));
        end
        
        % insert ROI title
        if roititle>0 | rls>0
            str='';
            if roititle>0
                str=[roitmp.id ' - '];
            end
            

            
            for i=1:numel(frames)
               % str='';
                if rls==1
                    pir=find(rlsresults.totaltime>=frames(i),1,'first')-1;
                    if numel(pir)==0
                        pir=length(rlsresults.totaltime); 
                    end
                    pit=find(rlstraining.totaltime>=frames(i),1,'first')-1;
                    if numel(pit)==0
                        pit=length(rlstraining.totaltime); 
                    end
                    
                    if numel(training)
                        str=[str num2str(pit) ' - '];
                    end
                    
                    str=[str  num2str(pir)];
                end
                
 
                imout(:,:,:,i)=insertText( imout(:,:,:,i),[1 1],str,'Font','Arial','FontSize',10,'BoxColor',...
                    [1 1 1],'BoxOpacity',0.0,'TextColor','white','AnchorPoint','LeftTop');
            end
        end

        startx=0;
        wid=7;
        offsettrain=0;
        
        if numel(training) % display training classes
            ncla=numel(roitmp.classes);
            cmap=prism(ncla);
            if ncla==0
                disp('No class available in this ROI; There is likely no training for this classification... ');
                idtrain=[];
            else
                inte=uint16(double(size(imout,1)-shifty)/double(ncla+1));
                
                startx=2;
                if isfield(roitmp.train,strid)
                    idtrain=roitmp.train.(strid).id;
                    offsettrain=wid;
                else
                    idtrain=[];
                end
            end
        end
        
        if numel(results) % display results classes
            if isfield(roitmp.results,strid)
                ncla=numel(roitmp.results.(strid).classes);
                cmap=prism(ncla);
            else
                ncla=0;
            end
            if ncla==0
                disp('No class available in this ROI; There is no results for this classification... ');
                idresults=[];
            else
                inte=uint16(double(size(imout,1)-shifty)/double(ncla+1));
                startx2=startx+offsettrain+2;
                if isfield(roitmp.results,strid)
                    idresults=roitmp.results.(strid).id;
                else
                    idresults=[];
                end
            end
        end
        
        %===RECTANGLES===
        for ii=1:numel(frames)
            if numel(training) && numel(idtrain)
                for jj=1:ncla
                    imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'Rectangle',[startx inte*jj-inte/2+shifty wid wid],...
                        'Color', {'white'},'Opacity',1);
                    if idtrain(frames(ii))==jj
                        col=round(65535*cmap(jj,:));
                        imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'FilledRectangle',[startx+1 inte*jj-inte/2+1+shifty wid-2 wid-2],'Color',col,'Opacity',1 );
                    end
                end
            end
            if numel(results) && numel(idresults)
                for jj=1:ncla
                    imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'Rectangle',[startx2 inte*jj-inte/2+shifty wid wid],...
                        'Color', {'white'},'Opacity',1);
                    if idresults(frames(ii))==jj
                        col=round(65535*cmap(jj,:));
                        imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'FilledRectangle',[startx2+1 inte*jj-inte/2+1+shifty wid-2 wid-2],'Color',col,'Opacity',1 );
                    end
                end
            end
            
        end
        imgout(1+(k-1)*h:k*h,1+(j-1)*w:j*w,:,:)=imout; % assemble rois
        cc=cc+1;
    end
end

%imgout=imgout(:,:,:,frames);
imgout=uint8(double( imgout)/256);


%rows on the top of the movie : framerate or title
if framerate>0 || numel(title)
    shifttitley=fontsize+10;
    imgout2=cat(1,uint8(zeros(shifttitley,size(imgout,2),size(imgout,3),size(imgout,4))),imgout);
    
    for j=1:numel(frames)
        timestamp=[num2str((j-1)*framerate) 'min'];        
        if numel(title)>0
            timestamp=[timestamp ' - ' title];
        end        
        imgout2(:,:,:,j)=insertText( imgout2(:,:,:,j),[1 5],timestamp,'Font','Arial','FontSize',fontsize,'BoxColor',...
            [1 1 1],'BoxOpacity',0.0,'TextColor','white','AnchorPoint','LeftTop');
    end
    imgout=imgout2;
end

% export parameters

if numel(name)==0
 %   name=[obj.path  '/ClassifMosaic'];
    
  %  for i=1:nmov
 %       name=[name '_' num2str(rois(i)) '_' num2str(rois(i)) '-'];
%    end
    if isa(obj,'classi')
        name=fullfile(obj.path, 'rois');
    end
    
    if isa(obj,'shallow')
        name=fullfile(obj.io.path,obj.io.file,'rois');
    end
    
    if isa(obj,'roi')
        name=fullfile(obj.path,obj.id);
    end

else
    if isa(obj,'classi')
        name=fullfile(obj.path,name);
    end
    
    if isa(obj,'shallow')
        name=fullfile(obj.io.path,obj.io.file,name);
    end
    
    if isa(obj,'roi')
        name=fullfile(obj.path,name);
    end
end
v=VideoWriter(name,'MPEG-4');
v.FrameRate=ips;
v.Quality=90;
open(v);

%return
writeVideo(v,imgout);
close(v);
disp(['Movie successfully exported to : ' name '.mp4'])


