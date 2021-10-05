function mosaic(obj,varargin)
% generates a rois movie with multiple cavities and rich features

% obj is the reference object: it can be either a @shallow, a @classi, or a
% @ROI.
% other arguments are expained below
stopWhenDead=[]; %dont show seg if cell is dead
shiftY=[];
hideStamp=0;
crop=[];
arraySize=[];
displayLegend=0;
snapRate=[];
scalingFactor=3;
legendX=0;
name=[];
ips=10;
framerate=5;
channel=2;
fontsize=15;
levels=[];
training=[];
results=[];
title=[];
strid='';
classif=[];

%classif.strid='';

roititle=0;
rls=0;
Flip=0;
rgb={};
contour=0;
sequence='Movie';
background=[0 0 0];
text=[1 1 1];

if isa(obj,'classi')
    %frames=1:size(obj.roi(1).image,4); % take the number of frames from the image list
    frames=[]; %auto determination later, if not indicated
    strid=obj.strid;
    rois=[1 2 3];
    classif=obj;
end
if isa(obj,'shallow')
    %frames=1:numel(obj.fov(1).srclist{1}); % take the number of frames from the image list
    frames=[]; %auto determination later, if not indicated
    rois=[1 1 1; 1 2 3];
end
if isa(obj,'roi')
    frames=1:size(obj.image,4); % take the number of frames from the image list
end


%%
for i=1:numel(varargin)
    
    if strcmp(varargin{i},'Frames')  frames=varargin{i+1};  end
    if strcmp(varargin{i},'Name')    name=varargin{i+1}; end
    
    if strcmp(varargin{i},'IPS') % number of frames displayed per second
        ips=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Framerate') % used to diplay the time on the movie
        framerate=varargin{i+1};
    end
    
    if strcmp(varargin{i},'SnapRate') % used to diplay the time on the movie
        snapRate=varargin{i+1};
    end
    
    if strcmp(varargin{i},'stopDead') % stop showing channel once cell is dead. Must give 'Classification'
        stopWhenDead=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Flip') % used to diplay the time on the movie
        Flip=1;
    end
    if strcmp(varargin{i},'HideStamp') %
        hideStamp=1;
        shiftY=1;
    end
    
    if strcmp(varargin{i},'NoColor') %
        nocolor=1;
    end
    
    if strcmp(varargin{i},'Channel') % an array that indicates the channels being displayed, can be scalar array or strid; Multiple channels will be overlaid on the same image
        channel=varargin{i+1};
        
        if numel(channel)==0
            disp('Channel is not found; quitting!');
            return;
        else
            if numel(snapRate)==0
                snapRate=ones(1,numel(channel));%freq=1 for all channel
            end
            if numel(stopWhenDead)==0
                stopWhenDead=zeros(1,numel(channel));
            end
        end
    end
    
    if strcmp(varargin{i},'Levels') % defines output levels for display; must be a 2D vector [low high] for 1D channels (glike a grayscale image) , and a colormap for indexed channels:  jet(16):
        % if several channels are to be overlaid, then a cell array of
        % string must be used : { [low high] , jet(16)}
        %-1 -1 = auto adjust
        levels=varargin{i+1};
    end
    
    if strcmp(varargin{i},'RGB') % defines the RGB levels for each channel / cell array of 3D vectors
        rgb=varargin{i+1};
    end
    
    if strcmp(varargin{i},'FontSize')
        fontsize=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Mosaic') %
        rois=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Training') % displays the training data (ground truth)
        training=1; %varargin{i+1};
    end
    
    if strcmp(varargin{i},'Results') %displays the classi results
        results=1;%varargin{i+1};
    end
    
    if strcmp(varargin{i},'Classification') % enters the strid of the classif to be included
        classif=varargin{i+1};
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
    
    if strcmp(varargin{i},'contour') %plots contours of indexed objects in case an indexed image is requested
        contour=1;
    end
    
    if strcmp(varargin{i},'Output') % outputs data as : 'Sequence' : sequence of images ; 'Movie' : mp4 movie; 'Mat': mat file of the output matrix
        sequence=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Background') % specifies the background color
        background=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Text') % specifies the text color
        text=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Legend') % display legend for classes
        legendX=varargin{i+1};
        displayLegend=1;
    end
    
    if strcmp(varargin{i},'Scale') % scale images up
        scalingFactor=varargin{i+1};
    end
    if strcmp(varargin{i},'Crop') % scale images up
        crop=varargin{i+1};
    end
    
    if strcmp(varargin{i},'ArraySize') % a 2 element vector that specifiies the number of row/col for the output matrix
        arraySize=varargin{i+1};
        nmov=size(rois,2);
        
    end
end
    %%
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
            if numel(classif.strid)==0
                disp('You need to provide the strid of the classification training/results to be displayed; Quitting ! ');
                return;
            end
        end
    end
    
    %%
    if numel(rois)
        nmov=size(rois,2);
        
        if numel(arraySize)
            nsize=arraySize;
            
               if nmov> arraySize(1) * arraySize(2)
            disp('Error : the number of ROIs exceeds the allocated space !');
            return
               end
        
        else
            nsize=[1 1; 1 2; 1 3; 2 2; 2 3; 2 3; 3 3; 3 3; 3 3];
            if nmov>9
                nsize=floor(sqrt(nmov-1))+1;
                nsize=[nsize nsize];
            else
                nsize=nsize(nmov,:);
            end
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
        
        %get max number of frames
        if numel(frames)==0
            maxframe=NaN;
            for r=rois
                obj.roi(r).load;
                maxframe=min(maxframe, min(size(obj.roi(r).image,4)));
            end
            frames=1:maxframe;
        end
    end
    
    if isa(obj,'shallow')
        img=obj.fov(rois(1,1)).roi(rois(2,1)).image;
        if numel(img)==0
            obj.fov(rois(1,1)).roi(rois(2,1)).load;
        end
        roitmp=obj.fov(rois(1,1)).roi(rois(2,1));
        
        %get max number of frames
        if numel(frames)==0
            maxframe=NaN;
            ccf=1;
            for r=rois(2,:)
                obj.fov(rois(2,ccf)).roi(r).load;
                maxframe=min(maxframe, min(size(obj.roi(r).image,4)));
                ccf=ccf+1;
            end
            frames=1:maxframe;
        end
        
    end
    
    if isa(obj,'roi')
        img=obj.image;
        if numel(img)==0
            obj.load;
        end
        roitmp=obj;
    end
    
    nframesref=size(roitmp.image,4);%useless?
    
    
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
        wid=ceil(7*sqrt(scalingFactor))+5; %width of squares
        shiftx=wid;
        shiftx=floor(shiftx*sqrt(scalingFactor));
    end
    if numel(results)
        wid=ceil(7*sqrt(scalingFactor))+5; %width of squares
        shiftx=shiftx+wid;
        shiftx=floor(shiftx*sqrt(scalingFactor));
    end
    
    if numel(results) | numel(training)
        legendX=ceil(legendX*sqrt(scalingFactor));
        shiftx=shiftx+legendX;
    end
    
    
    % add row for roi title
    shifty=0;
    if roititle>0 | rls>0 | shiftY
        shifty=16;
        shifty=floor(shifty*sqrt(scalingFactor));
    end
    
    %=creates the table
    if numel(crop)>0
        for c=1:size(img,3)
            for f=1:size(img,4)
                imgtp(:,:,c,f)=imcrop(img(:,:,c,f),crop);
            end
        end
        img=imgtp;
    end
    %scalingFactor
    img=imresize(img,scalingFactor);
    h=size(img,1)+shifty;
    w=size(img,2)+shiftx;
    imgout=uint16(65535*ones(nsize(1)*h,nsize(2)*w,3,numel(frames)));
    imgout(:,:,1,:)=imgout(:,:,1,:)*background(1);
    imgout(:,:,2,:)=imgout(:,:,2,:)*background(2);
    imgout(:,:,3,:)=imgout(:,:,3,:)*background(3);
    %=
    %figure, imshow(imgout(:,:,:,1))
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
            if numel(crop)>0
                for c=1:size(imtmp,3)
                    for f=1:size(imtmp,4)
                        imtmptp(:,:,c,f)=imcrop(imtmp(:,:,c,f),crop);
                    end
                end
                imtmp=imtmptp;
            end
            imtmp=imresize(imtmp,scalingFactor,'nearest');
            
            
            frameEnd(1:numel(cha))=9999;
            if numel(find(stopWhenDead==1))>0 %if channel to skip when cell is dead
                if numel(classif)>0
                    rlsresults=roitmp.results.(classif.strid).RLS;
                    frameEnd(find(stopWhenDead==1))=rlsresults.frameEnd;
                else
                    error('You want to hide a channel when cell is dead. You need to indicate a classi with Classification argument');
                end
            end
            
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
            %   imout(:,:,1,:)=imout(:,:,1,:)*background(1);
            %   imout(:,:,2,:)=imout(:,:,2,:)*background(2);
            %   imout(:,:,3,:)=imgout(:,:,3,:)*background(3);
            
            for i=1:size(imtmp,4) % loop on frames, to replace by frames
                
                %IMAGES
                imgRGBsum=uint16(zeros(size(imtmp,1),size(imtmp,2),3));
                for ii=1:numel(cha) %loop on channels
                    if mod(i-1, snapRate(ii))==0 %skip frames
                        if frames(i)<frameEnd(ii)  %stop when dead
                            imtmp2=imtmp(:,:,cha{ii},i);
                        else
                            imtmp2=uint16(zeros(size(imtmp(:,:,cha{ii},i))));
                        end
                    else
                        imtmp2=uint16(zeros(size(imtmp(:,:,cha{ii},i))));
                    end
                    if numel(cha{ii})==1 % single dimension channel => levels can be readjusted
                        if numel(levels{ii})==2 % A 2D vector is provided, therefore image is not an indexed one
                            if levels{ii}==[-1, -1]
                                imtmp2 = imadjust(imtmp2);
                            else
                                imtmp2 = imadjust(imtmp2,[levels{ii}(1)/65535 levels{ii}(2)/65535],[0 1]);
                            end
                            imtmp2= cat(3, imtmp2*rgb{ii}(1), imtmp2*rgb{ii}(2), imtmp2*rgb{ii}(3));
                            
                        else % channel represents an indexed image , will use provided colormap
                            maxe= max( imtmp2(:)); %get classes
                            imrgbbw=uint16(zeros(size(imgRGBsum)));
                            for iii=1:maxe %for classes
                                bw=imtmp2==iii;
                                if contour %plots the contour rather than a surface
                                    %bw=bwperim(bw); % ugly but proablably not
                                    %worse than what is done below in the end :
                                    [B,L] = bwboundaries(bw,'noholes');
                                    bw(:)=0;
                                    bw=65535*uint16(bw);
                                    vecpol=[];
                                    
                                    for m =1:length(B)
                                        boundary = B{m};
                                        if size(boundary,1)>2 % a polygon must have at least 3 vertices
                                            vecpoltmp=[boundary(:,2)' ; boundary(:,1)'];
                                            vecpoltmp=reshape(vecpoltmp,1,[]);
                                            bw= insertShape( bw,'Polygon',vecpoltmp,    'Color', round(65535*levels{ii}(iii,:)),'LineWidth',4,'SmoothEdges',true);
                                        end
                                    end
                                    imrgb=bw;
                                    
                                else % plots surface
                                    bw=65535*uint16(bw);
                                    imrgb=cat(3,bw*levels{ii}(iii,1)*rgb{ii}(1),bw*levels{ii}(iii,2)*rgb{ii}(2),bw*levels{ii}(iii,3)*rgb{ii}(3));
                                end
                                
                                %size(imrgb)
                                %size(imrgbbw)
                                
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
            end
            
            %the REST
            %add black rectangles top and left of each roi
            imblack=uint16(65535*ones(size(imtmp,1),shiftx,3,size(imtmp,4)));
            imblack(:,:,1,:)=imblack(:,:,1,:)*background(1);
            imblack(:,:,2,:)=imblack(:,:,2,:)*background(2);
            imblack(:,:,3,:)=imblack(:,:,3,:)*background(3);
            
            imout=cat(2,imblack,imout);
            imblack2=uint16(65535*ones(shifty,size(imout,2),3,size(imout,4)));
            imout=cat(1,imblack2,imout);
            %=
            
            % add black frame around ROIs
            framesize=2;
            for ci=1:3
                imout(1:framesize,:,ci,:)=65535*background(ci);
                imout(end-framesize+1:end,:,ci,:)=65535*background(ci);
                imout(:,1:framesize,ci,:)=65535*background(ci);
                imout(:,end-framesize+1:end,ci,:)=65535*background(ci);
            end
            
            % insert features here
            % =calculate RLS  based on measureRLS2
            if rls==1
                %   [rlsout,rlsresults,rlstraining]=measureRLS3(classif,roitmp);
                rlsresults=roitmp.results.(classif.strid).RLS;
                pir=0;
                if training==1
                    rlst=roitmp.train.(classif.strid).RLS;
                    pit=0;
                end
            end
            %=
            
            % insert ROI title
            if roititle>0 | rls>0
                str='';
                if roititle>0
                    str=[roitmp.id ' - '];
                end
                %NUMBER OF DIVS
                for i=1:numel(frames)
                    str='';
                    if rls==1
                        
                        pir=sum(frames(i)>=rlsresults.framediv);
                        if pir<10
                            str=[str  num2str(pir) '  - '];
                        else
                            str=[str num2str(pir) ' - '];
                        end
                        if numel(training)==0 %if only results
                            str=[];
                            str=[str  num2str(pir) ' divisions'];
                        end
                        
                        if training==1
                            pit=sum(frames(i)>=rlst.framediv);
                            if pit<10
                                str=[str ' ' num2str(pit) ' div'];
                            else
                                str=[str num2str(pit) ' div'];
                            end
                        end
                    end
                    %ndiv text
                    if numel(training)==1
                        imout(:,:,:,i)=insertText( imout(:,:,:,i),[legendX-30 shifty/2+2],str,'Font','Monospace 821 Bold BT','FontSize',floor(12*sqrt(scalingFactor)),'BoxColor',...
                            [1 1 1],'BoxOpacity',0.0,'TextColor',255*text,'AnchorPoint','LeftCenter');
                    elseif numel(training)==0 %if only results
                        imout(:,:,:,i)=insertText( imout(:,:,:,i),[2 shifty/2+2],str,'Font','Monospace 821 Bold BT','FontSize',floor(12*sqrt(scalingFactor)),'BoxColor',...
                            [1 1 1],'BoxOpacity',0.0,'TextColor',255*text,'AnchorPoint','LeftCenter');
                    end
                end
            end
            
            startx=0;
            offsettrain=0;
            
            %=====CLASSES
            if numel(results) || numel(training)
                classname=classif.classes;
            end
            
            if numel(results) % display results classes
                if isfield(roitmp.results,classif.strid)
                    ncla=numel(roitmp.results.(classif.strid).classes);
                    cmap=prism(ncla);
                    cmap(1,:)=[0.75,0.75,0.75];
                    if nocolor==1
                        cmap(:,:)=0.5;
                    end
                else
                    ncla=0;
                end
                if ncla==0
                    disp('No class available in this ROI; There is no results for this classification... ');
                    idresults=[];
                else
                    inte=uint16(double(size(imout,1)-shifty)/double(ncla));
                    startx=shiftx-ceil(2*sqrt(scalingFactor)) -(numel(results)+numel(training))*wid;
                    
                    if isfield(roitmp.results,classif.strid)
                        idresults=roitmp.results.(classif.strid).id;
                    else
                        idresults=[];
                    end
                end
            end
            
            if numel(training) % display training classes
                ncla=numel(roitmp.classes);
                cmap=prism(ncla);
                                    cmap(1,:)=[0.75,0.75,0.75];

                if ncla==0
                    disp('No class available in this ROI; There is likely no training for this classification... ');
                    idtrain=[];
                else
                    inte=uint16(double(size(imout,1)-shifty)/double(ncla));
                    if isfield(roitmp.train,classif.strid)
                        idtrain=roitmp.train.(classif.strid).id;
                        offsettrain=wid+4;
                        startx2=startx+offsettrain;
                    else
                        idtrain=[];
                    end
                end
            end
            
            for ii=1:numel(frames)
                %===CLASS RECTANGLES===
                if numel(results) && numel(idresults)
                    for jj=1:ncla
                        col=round(65535*cmap(jj,:));
                        if idresults(frames(ii))==jj
                            imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'FilledRectangle',[startx inte*jj-inte/2+shifty-wid/2 wid wid],'Color',col,'Opacity',1 );
                        end
                        imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'Rectangle',[startx inte*jj-inte/2+shifty-wid/2 wid wid],...
                            'Color', 65535*text,'Opacity',1,'LineWidth',2);
                        if displayLegend==1
                            imout(:,:,:,ii) = insertText(imout(:,:,:,ii),[shiftx-(numel(results)+numel(training))*wid-5, inte*jj-inte/2+shifty],classname{jj},'Font','Arial Bold','FontSize',20, 'TextColor',col,'BoxColor',[1 1 1],'BoxOpacity',0.0,'AnchorPoint','RightCenter');
                        end
                    end
                end
                
                if numel(training) && numel(idtrain)
                    for jj=1:ncla
                        col=round(65535*cmap(jj,:));
                        if idtrain(frames(ii))==jj
                            imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'FilledRectangle',[startx2 inte*jj-inte/2+shifty-wid/2 wid wid],'Color',col,'Opacity',1 );
                        end
                        imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'Rectangle',[startx2 inte*jj-inte/2+shifty-wid/2 wid wid],...
                            'Color', 65535*text,'Opacity',1,'LineWidth',2);
                        if displayLegend==1
                            imout(:,:,:,ii) = insertText(imout(:,:,:,ii),[shiftx-(numel(results)+numel(training))*wid-5, inte*jj-inte/2+shifty],classname{jj},'Font','Arial Bold','FontSize',20, 'TextColor',col,'BoxColor',[1 1 1],'BoxOpacity',0.0,'AnchorPoint','RightCenter');
                        end
                    end
                end
                
                
            end
            imgout(1+(k-1)*h:k*h,1+(j-1)*w:j*w,:,:)=imout; % assemble rois
            cc=cc+1;
        end
    end
    
    %figure, imshow(imgout(:,:,:,1))
    %imgout=imgout(:,:,:,frames);
    imgout=uint8(double( imgout)/256);
    
    
    %rows on the top of the movie : framerate or title
    if framerate>0 || numel(title)
        shifttitley=floor(sqrt(scalingFactor)*fontsize)+10;
        topimage=uint8(255*ones(shifttitley,size(imgout,2),size(imgout,3),size(imgout,4)));
        for ci=1:3
            topimage(:,:,ci,:)=topimage(:,:,ci,:)*background(ci);
        end
        
        imgout2=cat(1,topimage,imgout);
        
        for j=1:numel(frames)
            timestamp=[num2str((frames(j)-frames(1))*framerate) 'min'];
            if hideStamp==1
                timestamp='';
            end
            if numel(title)>0
                timestamp=[title ' - ' timestamp];
            end
            imgout2(:,:,:,j)=insertText(imgout2(:,:,:,j),[1,shifttitley/2],timestamp,'Font','Arial Bold','FontSize',floor(sqrt(scalingFactor)*fontsize),...
                'BoxColor',[1 1 1],'BoxOpacity',0.0,'TextColor',255*text,'AnchorPoint','LeftCenter');
        end
        imgout=imgout2;
    end
    
    %%
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
%         if isa(obj,'classi')
%             name=fullfile(obj.path,name);
%         end
%         
%         if isa(obj,'shallow')
%             name=fullfile(obj.io.path,obj.io.file,name);
%         end
%         
%         if isa(obj,'roi')
%             name=fullfile(obj.path,name);
%         end
    end
    
    % routine output : movie or sequence of image
    
    switch sequence 
        case 'Movie' % movie / default
        
        v=VideoWriter(name,'MPEG-4');
        v.FrameRate=ips;
        v.Quality=100;
        open(v);
        
        %return
        writeVideo(v,imgout);
        close(v);
        disp(['Movie successfully exported to : ' name '.mp4'])
        
        case 'Sequence'
        
            if numel(arraySize)
                lin=arraySize(1);
            else
                lin=1;
            end
            
             h= figure, montage(imgout,'Size',[lin Inf]);
              exportgraphics(h, [ name '.pdf']);
              disp(['Montage figure successfully exported to : ' name '.pdf'])
              
        case 'Mat'
            save( [ name '.mat'], 'imgout');
             disp(['Mat file with matrix successfully exported to : ' name '.mat'])
    end
    
    
